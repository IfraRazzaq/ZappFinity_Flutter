import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Color.fromARGB(255, 30, 92, 143),
        hintColor: Color.fromARGB(255, 30, 92, 143),
      ),
      home: TodoList(),
    );
  }
}

class TodoItem {
  final String title;
  final String description;
  final String imageUrl;

  TodoItem({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}

class TodoList extends StatefulWidget {
  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  User? _user;
  List<TodoItem> todos = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    List<TodoItem> todoList = [];

    try {
      if (_user != null) {
        final QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('todos')
            .where('uid', isEqualTo: _user!.uid)
            .get();

        todoList = snapshot.docs.map((DocumentSnapshot document) {
          final Map<String, dynamic>? data =
              document.data() as Map<String, dynamic>?;

          if (data != null &&
              data.containsKey('title') &&
              data.containsKey('description')) {
            return TodoItem(
              title: data['title'],
              description: data['description'],
              imageUrl: data['imageUrl'] ?? '',
            );
          } else {
            return TodoItem(
              title: 'Title Missing',
              description: 'Description Missing',
              imageUrl: '',
            );
          }
        }).toList();
      }
    } catch (e) {
      print('Error fetching to-do items: $e');
    }
    setState(() {
      todos = todoList;
    });
  }

  void _addTodo() async {
    File? _imageFile;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add what To-Do'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile =
                      await picker.pickImage(source: ImageSource.gallery);

                  if (pickedFile != null) {
                    setState(() {
                      _imageFile = File(pickedFile.path);
                    });
                  } else {
                    // Handle the case where the user canceled image selection
                  }
                },
                child: Text('Select Image'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                String title = _titleController.text.trim();
                String description = _descriptionController.text.trim();

                if (title.isNotEmpty && _user != null) {
                  final newTodoRef =
                      await FirebaseFirestore.instance.collection('todos').add({
                    'uid': _user!.uid,
                    'title': title,
                    'description': description,
                    'imageUrl': '', // Store the image URL in Firestore
                  });

                  await _uploadImageToFirestore(newTodoRef.id, _imageFile!);
                  _fetchTodos();
                }

                _titleController.clear();
                _descriptionController.clear();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                _titleController.clear();
                _descriptionController.clear();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadImageToFirestore(String todoId, File imageFile) async {
    if (imageFile != null) {
      try {
        final fileName = 'todo_images/$todoId.png';
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        final uploadTask = storageRef.putFile(imageFile);

        await uploadTask.whenComplete(() async {
          final imageUrl = await storageRef.getDownloadURL();

          await FirebaseFirestore.instance
              .collection('todos')
              .doc(todoId)
              .update({
            'imageUrl': imageUrl,
          });

          _fetchTodos();
        });
      } catch (e) {
        print('Error uploading image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.account_circle),
            onPressed: () {
              // Handle profile button click
            },
          ),
        ],
      ),
      body: _currentIndex == 0
          ? ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];

                return ListTile(
                  title: Text(todo.title),
                  subtitle: Text(todo.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          // Handle edit button click
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {},
                      ),
                    ],
                  ),
                );
              },
            )
          : Center(
              child: Text('Friends Screen Content'),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.check),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _addTodo,
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}