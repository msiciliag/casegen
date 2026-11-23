# Meeting audio

CaseGen ships two prerecorded MP3s per scripted meeting, one in Spanish and one in English. The cast performs the original dialogue in each case’s `scene.lines`. All participants are fictional characters in a simulation. The recordings use stock synthetic voices.

## Rendering locally

Install FFmpeg with the `libmp3lame` encoder. In a Python 3.12 virtual environment, install the renderer dependencies.

```sh
python -m pip install kokoro-onnx==0.6.1 onnxruntime==1.32.0 numpy==2.5.5 soundfile==0.14.0
```

Download `kokoro-v1.0.onnx` and `voices-v1.0.bin` into the same local directory. Compare their SHA-256 sums with the publisher’s release before rendering. The command runs inference on the CPU and only requires the downloaded files. [ONNX model files](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1)

| File | SHA-256 |
| --- | --- |
| kokoro-v1.0.onnx | `beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a` |
| voices-v1.0.bin | `bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d` |

```sh
python editorial/render_scenes.py --models /path/to/model/files netflix
python editorial/render_scenes.py --models /path/to/model/files --lang en news-2026-11-spotify-authors
```

Omit case IDs to render the whole catalogue. The script takes text, character labels and versioned filenames from the same JSON the game reads. The first speaker introduces the scene or speaks as the player. The second plays the stakeholder. Edit the cast in `render_scenes.py` for a new voice pairing. For changes to a published recording, increment its filename version in both translations before rendering. Listen to each exported file alongside its transcript, including names, acronyms and quantities.

The renderer uses 24 kHz mono speech, separate voices for each role, a short pause at each change of speaker and MP3 encoding at 96 kbps. The mastering filter targets −16 LUFS and a −2 dB true-peak ceiling before encoding.

## Model and voice provenance

Hexgrad distributes Kokoro v1.0 and its bundled voice profiles under the model repository’s Apache 2.0 license. Its model card documents training on permissively licensed, public-domain and synthetic material, credits the contributing CC BY datasets, and expressly welcomes production and commercial deployments. The voice directory lists the profiles available by language. CaseGen distributes its rendered dialogue. The model, profile files and inference engine stay on the editorial machine. [Kokoro model card and attributions](https://huggingface.co/hexgrad/Kokoro-82M) · [Voice profiles](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md) · [ONNX renderer and license](https://github.com/thewh1teagle/kokoro-onnx)
