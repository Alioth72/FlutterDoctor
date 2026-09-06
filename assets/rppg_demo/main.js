/*
* main.js
* The pipeline and MediaPipe processing (MediaPipe does not work in WebWorkers)
* */

// document.getElementById("authorization").addEventListener("click", () => {
//     navigator.mediaDevices.getUserMedia({
//         video: true,
//     }).then((stream) => {
//         if (stream) {
//             stream.getTracks().forEach(track => track.stop());
//             location.reload();
//         }
//     });
// });

// const cameraSelect = document.getElementById("cameraSelectDropdown");

// async function getCameraList() {
//     const devices = await navigator.mediaDevices.enumerateDevices();
//     const videoDevices = devices.filter(device => device.kind === "videoinput");
//     cameraSelect.options.length = 0;
//     videoDevices.forEach((device) => {
//         cameraSelect.options.add(new Option(device.label, device.deviceId));
//     });
// }
//
// getCameraList().then(() => {
//     cameraReady = true;
//     cameraButton.disabled = !ready();
// });

const cameraButton = document.getElementById("switchButton");
const previewCanvas = document.getElementById("previewCanvas");
const overlayCanvas = document.getElementById("overlayCanvas");
const previewCtx = previewCanvas.getContext("2d");
const faceCanvas = document.createElement("canvas");
const faceCtx = faceCanvas.getContext("2d");
const plotCanvas = document.getElementById("plotCanvas");
const plotCtx = plotCanvas.getContext("bitmaprenderer");
const inferenceDelayValue = document.getElementById("inferenceDelayValue");
const heartRateValue = document.getElementById("heartRateValue");
heartRateValue.style.color = "blue";
const inferenceFpsValue = document.getElementById("inferenceFpsValue");
const lambdaValue = document.getElementById("lambdaValue");
const lambdaValueDisplay = document.getElementById("lambdaValueDisplay");

let lambda = 1;

lambdaValue.addEventListener("input", (event) => {
    lambda = Math.pow(10, parseFloat(event.target.value));
    lambdaValueDisplay.innerText = `${lambda.toFixed(3)}`;
});

let video = document.getElementById("videoInput");

// let cameraReady = false;
let modelReady = false;
let stateReady = false;
let welchReady = false;
let hrReady = false;
// const ready = () => cameraReady && modelReady && stateReady && welchReady && hrReady;
const ready = () => modelReady && stateReady && welchReady && hrReady;

// const isApplePlatform = () => {
//     const isApple = /iPad|iPhone|iPod|Macintosh/.test(navigator.userAgent) && !window.MSStream;
//     // const isApple = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
//     const supportsRVFC = 'requestVideoFrameCallback' in HTMLVideoElement.prototype;
//     return isApple || !supportsRVFC;
//     // return !('requestVideoFrameCallback' in HTMLVideoElement.prototype);
// };

// Pre-allocated reusable canvas for 36x36 model inputs to eliminate per-frame GC allocations
const resizedCanvas = document.createElement("canvas");
resizedCanvas.width = 36;
resizedCanvas.height = 36;
const resizedCtx = resizedCanvas.getContext("2d", { willReadFrequently: true });
resizedCtx.imageSmoothingEnabled = true;
resizedCtx.imageSmoothingQuality = "high";

// Detect whether modern requestVideoFrameCallback (RVFC) is supported.
// Android Chromium supports RVFC; only Safari on iOS falls back to requestAnimationFrame.
const isApplePlatform = () => {
    return !('requestVideoFrameCallback' in HTMLVideoElement.prototype);
};

console.log(`Using requestAnimationFrame fallback: ${isApplePlatform()}`);

//const isApplePlatform = () => true

import { FaceDetector, FilesetResolver } from "https://fastly.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.4";

class KalmanFilter1D {
    constructor(processNoise, measurementNoise, initialState, initialEstimateError) {
        this.processNoise = processNoise;
        this.measurementNoise = measurementNoise;
        this.estimate = initialState;
        this.estimateError = initialEstimateError;
    }

    update(measurement) {
        const prediction = this.estimate;
        const predictionError = this.estimateError + this.processNoise;
        const kalmanGain = predictionError / (predictionError + this.measurementNoise);
        this.estimate = prediction + kalmanGain * (measurement - prediction);
        this.estimateError = (1 - kalmanGain) * predictionError;

        return this.estimate;
    }
}

let kfOriginX = null;
let kfOriginY = null;
let kfWidth = null;
let kfHeight = null;
let kfOutput = null;
let kfHr = null;


let faceDetector = null;

async function initializeFaceDetector() {
    const vision = await FilesetResolver.forVisionTasks(
        "https://fastly.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.4/wasm"
    );
    faceDetector = await FaceDetector.createFromOptions(vision, {
        baseOptions: {
            modelAssetPath: `blaze_face_short_range.tflite`,
            delegate: "CPU",
        },
        runningMode: "VIDEO",
        minDetectionConfidence: 0.5,
    });
}

let stream = null;
let isCameraOn = false;
let rafHandle = null;

let timestampArray = [];
let welchTimestamps = [];
let frameDetectionCounter = 0;
let lastBoundingBox = null;
let lastDetectorTimestamp = 0;

async function initFaceDetector() {
    if (!faceDetector){
        await initializeFaceDetector();
    }
    console.log(`Face Detector OK state: ${!!faceDetector}`);
}

initFaceDetector().then();

function stopCamera() {
    console.log("stop");
    isCameraOn = false;
    frameDetectionCounter = 0;
    lastBoundingBox = null;
    if (stream) {
        stream.getTracks().forEach(track => {
            track.stop();
            track.enabled = false;
        });
        stream = null;
    }
    if (video) {
        video.pause();
        if (typeof video.cancelVideoFrameCallback === 'function' && rafHandle) {
            try { video.cancelVideoFrameCallback(rafHandle); } catch (e) {}
        } else if (rafHandle) {
            try { cancelAnimationFrame(rafHandle); } catch (e) {}
        }
        video.srcObject = null;
    }
    rafHandle = null;
    plotWorker.postMessage({output: null});
    cameraButton.textContent = "Start";
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
    const overlayCtx = overlayCanvas.getContext("2d");
    overlayCtx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
    timestampArray = [];
    welchTimestamps = [];
    kfHr = null;
    kfOutput = null;
    heartRateValue.textContent = "NaN";
    heartRateValue.style.color = "blue";
}

function startFrameProcessing() {
    if (!isApplePlatform()) {
        rafHandle = video.requestVideoFrameCallback(processFrame);
    } else {
        let lastCall = 0;
        const fpsInterval = 1000 / 30; //以最高30fps的速率轮询

        const animate = (now) => {
            if (!isCameraOn) return;

            const elapsed = now - lastCall;
            if (elapsed > fpsInterval) {
                lastCall = now - (elapsed % fpsInterval);

                const metadata = {
                    mediaTime: video.currentTime,
                    presentedFrames: 0,
                    width: video.videoWidth,
                    height: video.videoHeight
                };
                processFrame(performance.now(), metadata).then();
            }
            requestAnimationFrame(animate);
        };
        requestAnimationFrame(animate);
    }
}

async function toggleCamera() {
    if (isCameraOn) {
        stopCamera();
        return;
    }
    try {
        console.log("toggleCamera: requesting media stream...");
        // Request camera with fallback for emulators without facingMode: user
        try {
            stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    width: { ideal: 640 },
                    height: { ideal: 480 },
                    frameRate: { ideal: 30 },
                    facingMode: "user"
                },
                audio: false,
            });
        } catch (constraintError) {
            console.warn("facingMode:user failed, trying fallback video: true", constraintError);
            stream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: false,
            });
        }

        if (!video) {
            video = document.getElementById("videoInput");
        }

        const updateCanvasDimensions = () => {
            if (video.videoWidth > 0 && video.videoHeight > 0) {
                previewCanvas.width = video.videoWidth;
                previewCanvas.height = video.videoHeight;
                overlayCanvas.width = video.videoWidth;
                overlayCanvas.height = video.videoHeight;
                console.log(`Canvas synced to video: ${video.videoWidth}x${video.videoHeight}`);
            }
        };

        video.onloadedmetadata = updateCanvasDimensions;
        video.srcObject = stream;

        await video.play();
        console.log('Video playback started successfully, size:', video.videoWidth, 'x', video.videoHeight);
        updateCanvasDimensions();

        isCameraOn = true;
        cameraButton.textContent = "Stop";
        startFrameProcessing();

    } catch (error) {
        console.error('Camera error:', error.name, error.message);
        alert(`Camera start failed: ${error.message}\nMake sure camera permission is granted.`);
        stopCamera();
    }
}

//cameraButton.addEventListener("click", toggleCamera);

cameraButton.addEventListener("click", () => {
        if (!faceDetector) {
            initFaceDetector().then();
        }
        toggleCamera().then();
     });

const onnxWorker = new Worker("onnxWorker.js");
onnxWorker.onerror = (err) => {
    console.error("onnxWorker runtime error:", err);
    inputQueueCount = 0;
};
const plotWorker = new Worker("plotWorker.js");
const welchWorker = new Worker("welchWorker.js");

let welchArray = new Array(300).fill(0);
let welchCount = 300-90;

let inferenceTimestamp = 0;
let inferenceCount = 0;
let inputQueueCount = 0;
let dropCount = 30;

onnxWorker.onmessage = (event) => {
    try {
        const { type } = event.data;
        if (type === "ready") {
            const { which } = event.data;
            switch (which) {
                case "model":
                    modelReady = true;
                    break;
                case "state":
                    stateReady = true;
                    break;
            }
            console.log(`onnxWorker ready: ${which}. Overall ready: ${ready()}`);
            return;
        }
        inputQueueCount = Math.max(0, inputQueueCount - 1);
        if (type === "error") return;
        const { output, timestamp, delay } = event.data;
        if (output === undefined || output === null) return;
        if (dropCount) return dropCount--;
        if (!kfOutput) {
            const processNoise = 1;
            const measurementNoise = 0.5;
            kfOutput = new KalmanFilter1D(processNoise, measurementNoise, output, 1);
        } else {
            kfOutput.update(output);
        }
        inferenceCount++;
        if (inferenceCount === 30) {
            inferenceFpsValue.textContent = `${(30 / ((timestamp - inferenceTimestamp) / 1000)).toFixed(1)}`;
            inferenceTimestamp = timestamp;
            inferenceCount = 0;
        }
        inferenceDelayValue.textContent = delay;
        if (welchArray.length >= 300) {
            welchArray.shift();
        }
        welchArray.push(kfOutput.estimate);
        welchTimestamps.push(timestamp);
        if (welchTimestamps.length > 300) {
            welchTimestamps.shift();
        }
        welchCount++;
        plotWorker.postMessage({
            output: kfOutput.estimate,
        });
        if (welchCount >= 300) {
            welchWorker.postMessage({input: new Float32Array(welchArray)});
            welchCount = 270;
        }
    } catch (err) {
        console.error("Error in onnxWorker.onmessage:", err);
    }
};

plotWorker.onmessage = (event) => {
    const { imageBitmap } = event.data;
    plotCtx.transferFromImageBitmap(imageBitmap);
}

let MeanHRErr = 0.04;

welchWorker.onmessage = (event) => {
    const { type } = event.data;
    if (type === "ready") {
        const { which } = event.data;
        switch (which) {
            case "welch":
                welchReady = true;
                break;
            case "hr":
                hrReady = true;
                break;
        }
        console.log(`welchWorker ready: ${which}. Overall ready: ${ready()}`);
        return;
    }
    let { hr } = event.data;
    if (typeof hr !== 'number' || isNaN(hr) || hr <= 0) {
        return;
    }

    console.log(`Model Heart Rate: ${hr.toFixed(1)} BPM`);

    if (!kfHr) {
        const processNoise = 1.0;
        const measurementNoise = 2.0;
        kfHr = new KalmanFilter1D(processNoise, measurementNoise, hr, 1);
    } else {
        kfHr.update(hr);
    }

    MeanHRErr = 0.8 * MeanHRErr + 0.2 * Math.abs(kfHr.estimate - hr) / Math.max(1, hr);
    if ((MeanHRErr < 0.025) && (heartRateValue.style.color === "blue")) {
        heartRateValue.style.color = "red";
    }
    if ((MeanHRErr > 0.035) && (heartRateValue.style.color === "red")) {
        heartRateValue.style.color = "blue";
    }
    heartRateValue.textContent = kfHr.estimate.toFixed(1);
    console.log("Updated live HR:", kfHr.estimate.toFixed(1));
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onHeartRate', parseFloat(kfHr.estimate.toFixed(1)));
    }
}

function cropAndResizeUsingBoundingBox(canvas, boundingBox) {
    const x = Math.max(0, boundingBox.originX);
    const y = Math.max(0, boundingBox.originY);
    const width = Math.min(boundingBox.width, canvas.width - x);
    const height = Math.min(boundingBox.height, canvas.height - y);

    if (width <= 0 || height <= 0) return null;

    // Single-pass direct GPU crop and resize into pre-allocated 36x36 canvas (zero GC allocations)
    resizedCtx.drawImage(canvas, x, y, width, height, 0, 0, 36, 36);
    return resizedCanvas;
}

let lastTime = 0;
let mediaTime = 0;
async function processFrame(now, metadata) {
    if (!isCameraOn) {
        return;
    }
    try {
        // High-resolution presentation timestamp
        mediaTime = (typeof now === 'number' && now > 0) ? (now / 1000) : (performance.now() / 1000);
        lastTime = mediaTime;
        timestampArray.push(lastTime);
        if (timestampArray.length > 301) {
            timestampArray.shift();
        }

        // Camera video preview MUST be drawn unconditionally every frame
        previewCtx.drawImage(video, 0, 0, previewCanvas.width, previewCanvas.height);

        if (faceDetector) {
            frameDetectionCounter++;
            const shouldRunDetector = !lastBoundingBox || (frameDetectionCounter % 3 === 0);

            if (shouldRunDetector) {
                let nowMs = performance.now();
                if (nowMs <= lastDetectorTimestamp) {
                    nowMs = lastDetectorTimestamp + 1;
                }
                lastDetectorTimestamp = nowMs;

                const result = faceDetector.detectForVideo(video, nowMs);
                const detections = result ? result.detections : null;

                if (detections && detections.length > 0) {
                    const rawBoundingBox = detections[0].boundingBox;
                    if (!kfOriginX) {
                        const processNoise = 1e-2;
                        const measurementNoise = 5e-1;
                        kfOriginX = new KalmanFilter1D(processNoise, measurementNoise, rawBoundingBox.originX, 1);
                        kfOriginY = new KalmanFilter1D(processNoise, measurementNoise, rawBoundingBox.originY, 1);
                        kfWidth = new KalmanFilter1D(processNoise, measurementNoise, rawBoundingBox.width, 1);
                        kfHeight = new KalmanFilter1D(processNoise, measurementNoise, rawBoundingBox.height, 1);
                    } else {
                        kfOriginX.update(rawBoundingBox.originX);
                        kfOriginY.update(rawBoundingBox.originY);
                        kfWidth.update(rawBoundingBox.width);
                        kfHeight.update(rawBoundingBox.height);
                    }
                    const filteredBoundingBox = {
                        originX: kfOriginX.estimate,
                        originY: kfOriginY.estimate,
                        width: kfWidth.estimate,
                        height: kfHeight.estimate
                    };
                    filteredBoundingBox.height *= 1.2;
                    filteredBoundingBox.originY -= filteredBoundingBox.height * 0.2;
                    lastBoundingBox = filteredBoundingBox;
                } else {
                    lastBoundingBox = null;
                    const overlayCtx = overlayCanvas.getContext("2d");
                    overlayCtx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);
                }
            }

            if (lastBoundingBox) {
                drawBoundingBox(lastBoundingBox);
                const faceImage = cropAndResizeUsingBoundingBox(previewCanvas, lastBoundingBox);
                if (faceImage && inputQueueCount < 2) {
                    const imageData = resizedCtx.getImageData(0, 0, 36, 36);
                    const input = new Float32Array(36 * 36 * 3);

                    for (let i = 0; i < imageData.data.length; i += 4) {
                        const index = i / 4;
                        input[index * 3] = imageData.data[i] / 255;
                        input[index * 3 + 1] = imageData.data[i + 1] / 255;
                        input[index * 3 + 2] = imageData.data[i + 2] / 255;
                    }
                    inputQueueCount += 1;
                    onnxWorker.postMessage({ type: "data", input, timestamp: lastTime, lambda });
                }
            }
        }
    } catch (frameErr) {
        console.warn("Frame processing error caught:", frameErr);
    } finally {
        if (isCameraOn && video && !isApplePlatform()) {
            rafHandle = video.requestVideoFrameCallback(processFrame);
        }
    }
}

function drawBoundingBox(boundingBox) {

    const ctx = overlayCanvas.getContext("2d");
    ctx.clearRect(0, 0, overlayCanvas.width, overlayCanvas.height);

    ctx.strokeStyle = "#FF0000";
    ctx.lineWidth = 2;
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.rect(
        boundingBox.originX,
        boundingBox.originY,
        boundingBox.width,
        boundingBox.height
    );
    ctx.stroke();
}
