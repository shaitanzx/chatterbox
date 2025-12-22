# 🌍 Multilingual Chatterbox TTS Server for Windows PC
# Portable Installer Build by LeeAeron / @li_aeron
# Git: https://github.com/LeeAeron/chatterbox

## ✨ Key Features

🌐 **24+ Languages:** Arabic, Chinese, Danish, Dutch, English, Finnish, French, German, Greek, Hebrew, Hindi, Italian, Japanese, Korean, Malay, Norwegian, Polish, Portuguese, Russian, Spanish, Swedish, Swahili, Turkish
🌐 **All languages already available for usage**

🎤 **Voice Cloning:** Clone any voice using reference audio files
🎤 **Enhanced reference oice lenght of 10 minutes (beta)**

🎤 **Stress marks detection for russian language and setup** Enter propmpt in russian with stress marks or tap on RUStress button to set them up and get realism-like voice!
🎤 **Edit your own local stress marks vocabulary  by edit accent_fixes.yaml file**

📚 **Audiobook Generation:** Process entire books with automatic text chunking

⚡ **GPU Acceleration:** NVIDIA (CUDA) and AMD (ROCm) support

🌐 **Modern Web UI:** Intuitive interface with real-time audio playback

📡 **FastAPI Server:** RESTful API with interactive documentation

## 🔩 System Requirements

- **Windows 10/11** (64-bit) or **Linux**
- **Python 3.10+**
- **4GB+ RAM** (8GB+ recommended)
- **5GB+ storage** for models
- **GPU (Optional):** NVIDIA with 4GB+ VRAM or AMD RX 6000/7000 series

## 🎤 Voice Management

**Predefined Voices:** Place `.wav`/`.mp3` files in `./voices` directory

**Voice Cloning:** Upload reference audio via Web UI (stored in `./reference_audio`)

## ⚙️ Configuration

Edit `config.yaml` for settings:
```yaml
server:
  host: "127.0.0.1"
  port: 8004

tts_engine:
  device: "auto"  # auto, cuda, cpu
  
generation_defaults:
  temperature: 0.7
  language: "en"
```

## 📜 License

MIT License

## 🙏 Acknowledgements

- Original sources: THX to [Resemble AI](https://www.resemble.ai/) for [Chatterbox TTS](https://github.com/resemble-ai/chatterbox)

## Last version key changes:
- enhanced reference files lenght of 10 minutes (beta)
- all 24 languages already enabled and available
- autosaving last used language for next engine run (no need to select last used language again)
- stress marks for russian language detection and setup by RUStress button
- local stress marks vocabulary for russian language and not only russian. Just edit accent_fixes.yaml file, that already have examples. Easy to use.
- autosaing output audio files into /outputs folder. Changing audio compression format changes audio file format. No audio files local cache.
