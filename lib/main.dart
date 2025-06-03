import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String geminiApiKey =
    'AIzaSyB2vZltmPo5ydUzUhmovCgpxKJSLaNDiD4'; // Replace with valid API key

final Uri geminiUri = Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$geminiApiKey',
);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToDo App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const TodoHome(),
    );
  }
}

class Todo {
  String title;
  DateTime createdAt;
  bool isDone;
  DateTime? completedAt;

  Todo({
    required this.title,
    required this.createdAt,
    this.isDone = false,
    this.completedAt,
  });
}

class TodoHome extends StatefulWidget {
  const TodoHome({super.key});
  @override
  State<TodoHome> createState() => _TodoHomeState();
}

class _TodoHomeState extends State<TodoHome> {
  final List<Todo> _todos = [];
  final TextEditingController _controller = TextEditingController();

  void _addTodo() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _todos.add(Todo(
        title: _controller.text.trim(),
        createdAt: DateTime.now(),
      ));
      _controller.clear();
    });
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  void _editTodoDialog(int index) {
    final controller = TextEditingController(text: _todos[index].title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit ToDo"),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _todos[index].title = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _toggleComplete(int index) {
    setState(() {
      final todo = _todos[index];
      todo.isDone = !todo.isDone;
      todo.completedAt = todo.isDone ? DateTime.now() : null;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  Future<String> _generateSummary(List<Todo> completed) async {
    if (completed.isEmpty) return "You haven't completed any tasks today.";

    final list = completed.map((e) => "- ${e.title}").join("\n");
    final prompt = "Summarize these completed tasks:\n$list";

    try {
      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      });

      final response = await http.post(
        geminiUri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates != null &&
            candidates.isNotEmpty &&
            candidates[0]['content'] != null &&
            candidates[0]['content']['parts'] != null &&
            candidates[0]['content']['parts'].isNotEmpty) {
          return candidates[0]['content']['parts'][0]['text'] ??
              "No summary returned.";
        }
        return "No content returned by Gemini.";
      } else {
        return "Gemini API Error: ${response.statusCode} ${response.reasonPhrase}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  void _showSummary() async {
    final completed = _todos
        .where((t) =>
            t.isDone && t.completedAt != null && _isToday(t.completedAt!))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    final summary = await _generateSummary(completed);
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Today's AI Summary"),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ToDo + Gemini AI")),
      body: Column(
        children: [
          10.heightBox,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Add a task...",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.add), onPressed: _addTodo),
              ),
            ),
          ),
          16.heightBox,
          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text("No tasks yet!"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _todos.length,
                    itemBuilder: (_, index) {
                      final todo = _todos[index];
                      return Slidable(
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) => _editTodoDialog(index),
                              icon: Icons.edit,
                              backgroundColor: Colors.blue,
                            ),
                            SlidableAction(
                              onPressed: (_) => _deleteTodo(index),
                              icon: Icons.delete,
                              backgroundColor: Colors.red,
                            ),
                          ],
                        ),
                        child: ListTile(
                          tileColor: todo.isDone
                              ? Colors.green.shade100
                              : Colors.teal.shade50,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: Checkbox(
                            value: todo.isDone,
                            onChanged: (_) => _toggleComplete(index),
                          ),
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.isDone ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle:
                              Text("Added: ${_formatDate(todo.createdAt)}"),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ).pOnly(bottom: 12),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSummary,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.smart_toy),
      ),
    );
  }
}
