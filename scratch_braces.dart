import 'dart:io';
void main() {
  final file = File(r'c:\Users\manju\OneDrive\Documents\mj\lib\features\chatbot\screens\grapes_chatbot_screen.dart');
  final lines = file.readAsLinesSync();
  int braces = 0;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // This is naive, doesn't handle strings/comments, but should give a rough idea
    braces += line.split('{').length - 1;
    braces -= line.split('}').length - 1;
    if (braces == 0 && i > 50) {
      print('Braces reached 0 at line ${i+1}');
    }
  }
}
