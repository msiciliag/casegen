# <p align="center"> CaseGen </p>

<p align="center">
  <img src="./assets/logo.png" width="120" alt="CaseGen logo" />
</p>
<p align="center">
  Play the news. Step into the meeting, make the call, then find out what really happened.
</p>

### Concept

What would you charge for Netflix with ads? How would you admit 1,200 festival guests when the gate scanners keep losing their connection? CaseGen gives you the information available at decision time and asks you to defend a proposal.

The lead story turns a recent company announcement into a playable decision. Each story includes its date, a documented decision and what was known about the outcome when it was published. New editions can reach installed apps through the [editorial feed](editorial/README.md). The business archive contains three historical decisions with sources. Campo FDE contains five fictional client engagements for a forward deployed engineer. Each asks what you would deliver under the client's constraints and how you would tell whether it worked. Choose Español or English in Settings. The mobile interface, the cases and AI feedback use the selected language. Your saved proposals keep their original wording.

### Usage

1. **Choose a case.** Play the latest news edition, browse the archive, or take a field engineering assignment. Your progress counts distinct cases completed in each collection.
2. **Step into the meeting.** Listen to a short dramatization voiced in Spanish or English, or read the transcript. The case identifies your role, who you can speak to and what that person knows. You can ask three questions with your own AI connection. Audio supports background playback, seeking and speed controls.
3. **Make your call.** Pick a strategy and reveal the outcome immediately, or write the argument you would take into the room. You can also put forward a plan of your own. A local draft remembers your decision and interview when you leave.
4. **Compare approaches.** Reveal the documented decision or worked field example. News rounds finish with a two-option question about what the source actually confirms. Compare the trade-off behind your choice, then play another case. Completed rounds stay in your profile.
5. **Ask for feedback.** On mobile, configure your own API key and tap *Pedir réplica de IA*. CaseGen shows the destination and model before sending that case and your proposal directly to the provider.

The library opens immediately. In Profile you can set an optional name and practice preference, and revisit your answers. Settings guides you through choosing a provider, opening the Groq API Keys page and saving your key.

### Requirements

Download the Android APK from [GitHub Releases](https://github.com/msiciliag/casegen/releases). To run from source on Android or iOS, use `flutter pub get` and `flutter run`. Installing on a physical iPhone requires Apple signing.

The cases and history work offline. Opening source links and requesting AI feedback require internet access. For feedback, the default is Groq's `openai/gpt-oss-120b`. You can also enter an HTTPS Chat Completions endpoint and model that support OpenAI-compatible streaming. Manage or remove your key in *Settings*; it is stored in the device's secure storage.

### Stack

Flutter and SQLite on Android and iOS. The Python/Flet desktop edition shares the three business cases and saves proposals locally. To run it, install `requirements.txt` in a Python 3.11 virtual environment and run `python main.py` from the repository root.
