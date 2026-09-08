# ME-rPPG model provenance

- Source: https://github.com/KegangWangCCNU/ME-rPPG
- Source commit: `bec0855162a032832cfb71670c8ca7c79e218cd3`
- License: MIT; see `ME_RPPG_LICENSE.txt`.
- `me_rppg_model.onnx` is the repository's unmodified `model.onnx`.
- Model SHA-256: `9e0277fa4c0fb486c52818775fc83450901fc4d76e0ff98da64124443211e093`
- Source `state.json` SHA-256: `dfdc891f5485e497a0f6cfb5e68ae41e061f0588a83802bebe71a037c4ceb59c`
- `me_rppg_state.bin` is a lossless float32 conversion produced by
  `tool/convert_merppg_state.py`.
- Binary state SHA-256: `532cf0038ec5dc65235d7111660dbe46a4e8df4991245a906362d37ad6ce8cf8`

The runtime validates the expected 38-input/37-output model contract before
processing frames.
