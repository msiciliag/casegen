# <p align="center"> CaseGen </p>

<p align="center">
  <img src="./assets/logo.png" width="120" alt="CaseGen logo" />
</p>
<p align="center">
  Work through real business decisions and field engineering scenarios on your phone.
</p>

### Concept

What would you charge for Netflix with ads? How would you admit 1,200 festival guests when the gate scanners keep losing their connection? CaseGen gives you the information available at decision time and asks you to defend a proposal.

The business library contains three real decisions with sources. Campo FDE contains five fictional client engagements for a forward deployed engineer. Each asks what you would deliver under the client's constraints and how you would tell whether it worked. The cases are written in Spanish.

### Usage

1. **Choose a case.** Open Biblioteca for a business decision or Campo FDE for a client engagement.
2. **Make your call.** Write what you would do and save it. Your proposal stays in the local history.
3. **Compare approaches.** Discover what the company did, or compare your field plan with a worked example and a way to test it.
4. **Ask for feedback.** On mobile, configure your own API key and tap *Pedir réplica de IA*. CaseGen shows the destination and model before sending that case and your proposal directly to the provider.

### Requirements

Download the Android APK from [GitHub Releases](https://github.com/msiciliag/casegen/releases). To run from source on Android or iOS, use `flutter pub get` and `flutter run`. Installing on a physical iPhone requires Apple signing.

The cases and history work offline. Opening source links and requesting AI feedback require internet access. For feedback, the default is Groq's `openai/gpt-oss-120b`. You can also enter an HTTPS Chat Completions endpoint and model that support OpenAI-compatible streaming. Manage or remove your key in *Configurar IA*; it is stored in the device's secure storage.

### Stack

Flutter and SQLite on Android and iOS. The Python/Flet desktop edition shares the three business cases and saves proposals locally. To run it, install `requirements.txt` in a Python 3.11 virtual environment and run `python main.py` from the repository root.
