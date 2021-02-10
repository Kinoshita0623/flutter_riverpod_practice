import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final _uuid = Uuid();

final taskListProvider = StateNotifierProvider((_)=> TaskList(SQLiteTaskRepository(database: createDatabase())));

abstract class TaskRepository {

  Stream<TaskEvent> get taskEvents;

  Future<Task> add(Task task) async {
    throw Exception("インターフェースです");
  }

  Future<Task> find(String taskId) async {
    throw Exception("インターフェースです");
  }

  Future<List<Task>> findAll() async {
    throw Exception("インターフェースです");
  }

  Future<void> remove(String taskId) async {
    throw Exception("インターフェースです");
  }

  void dispose() {
    throw Exception("インターフェースです");
  }

}

class TaskEvent {
  TaskEvent({this.taskId, this.type});

  final Type type;
  final String taskId;
}

enum Type {
  UPDATED,
  CREATED,
  DELETED
}

Future<Database> createDatabase() async {
  var databasesPath = await getDatabasesPath();
  String path = join(databasesPath, "task.db");
  return await openDatabase(path, version: 1,
    onCreate: (Database db, int version) async {
      await db.execute('CREATE TABLE tasks(id TEXT PRIMARY KEY, title TEXT, done INTEGER NOT NULL)');
    }
  );
}

class InMemoryTaskRepository implements TaskRepository {
  final _taskMap = LinkedHashMap<String, Task>();
  final _eventStreamController = new StreamController<TaskEvent>.broadcast();
  Stream<TaskEvent> get taskEvents => _eventStreamController.stream;


  @override
  Future<Task> add(Task task) async{

    bool updated = _taskMap[task.id] != null;
    _taskMap[task.id] = task;
    Type eventType;
    if(updated){
      eventType = Type.UPDATED;
    }else{
      eventType = Type.CREATED;
    }
    _eventStreamController.sink.add(TaskEvent(taskId: task.id, type: eventType));
    return task;
  }

  @override
  Future<Task> find(String taskId) async{
    return _taskMap[taskId];
  }

  @override
  Future<List<Task>> findAll() async{
    return  _taskMap.values.toList();
  }

  @override
  Future<void> remove(String taskId) async{
    _taskMap.remove(taskId);
  }

  void dispose() {
    _eventStreamController.close();
  }
}

class SQLiteTaskRepository implements TaskRepository {
  SQLiteTaskRepository({this.database});

  final Future<Database> database;

  final _streamController = StreamController<TaskEvent>.broadcast();

  @override
  Stream<TaskEvent> get taskEvents => _streamController.stream;

  @override
  Future<Task> add(Task task) async{
    final db = await database;
    final batch = db.batch();
    final ex = await this.find(task.id);
    Type eventType;
    if(ex == null){
      eventType = Type.CREATED;
      batch.rawInsert('INSERT INTO tasks(id, title, done) values(?, ?, ?)', [task.id, task.title, task.done ? 1 : 0]);
    }else{
      eventType = Type.UPDATED;
      _update(task);
    }
    _streamController.add(TaskEvent(taskId: task.id, type: eventType));
    await batch.commit();
    return await find(task.id);
  }

  @override
  Future<List<Task>> findAll() async{
    final List<Map> list = await (await database).rawQuery('SELECT * FROM tasks');
    return list.map((Map map){
      return Task(
        id: map['id'],
        title: map['title'],
        done: map['done'] != 0
      );
    }).toList();
  }
  
  @override
  Future<Task> find(String taskId) async{
    final List<Map> list = await (await database).rawQuery("SELECT * FROM tasks WHERE id = ?", [taskId]);
    if(list.isEmpty){
      return null;
    }
    final map = list[0];
    return Task(
      id: map['id'],
      title: map['title'],
      done: map['done'] != 0
    );
  }
  
  Future<int> _update(Task task) async {
    return await (await database).rawUpdate('UPDATE tasks SET title = ?, done = ? WHERE id = ?', [task.title, task.done ? 1 : 0, task.id]);
  }

  @override
  Future<void> remove(String taskId) async{
    await (await database).rawDelete('DELETE FROM tasks WHERE id = ?', [taskId]);
  }

  @override
  void dispose() {
    _streamController.close();
  }
}


class Task {
  Task({
    this.title,
    this.done = false,
    String id,
  }) : id = id ?? _uuid.v4();
  final String id;
  final String title;
  final bool done;
}

void main() {
  runApp(ProviderScope(child: AppPage()));
}

class TaskList extends StateNotifier<List<Task>> {

  final TaskRepository taskRepository;
  TaskList(this.taskRepository) : super([]){
    taskRepository.findAll().then((List<Task> value) {
      this.state = value;
    });
  }



  void create(String title){
    print("create");
    final f = () async {
      await taskRepository.add(new Task(title: title));

      return await taskRepository.findAll();
    };
    f().then((list){
      print("created:${list.length}");
      this.state = list;
    });

  }
  
  void updateTitle({String id, String title}) async{
    final task = await taskRepository.find(id);
    final updated = new Task(id: task.id, title: title, done: task.done);
    await taskRepository.add(updated);
    this.state = await taskRepository.findAll();
  }

  void toggleDone(String id) async{
    final task = await taskRepository.find(id);
    final updated = new Task(id: task.id, title: task.title, done: !task.done);
    await taskRepository.add(updated);
    this.state = await taskRepository.findAll();
  }

  void delete(String id) async{
    await taskRepository.remove(id);
    this.state = await taskRepository.findAll();
  }


  void clear() {
    this.state = [];
  }

  void dispose() {

  }

}


class AppPage extends HookWidget {

  @override
  Widget build(BuildContext context) {


    return MaterialApp(
      
      routes: <String, WidgetBuilder>{
        "/": (BuildContext context) => TaskListPage(),
        "/create": (BuildContext context) => TaskEditorPage(),
      },
      initialRoute: "/",


    );



  }
}


class TaskListPage extends HookWidget {

  @override
  Widget build(BuildContext context) {
    final allTasks = useProvider<List<Task>>(taskListProvider.state);
    return DefaultTabController(
      child: Scaffold(
        appBar: AppBar(
          title: Text('タスク一覧'),
          bottom: TabBar(
              tabs: [
                Tab(
                    text: "未達成"
                ),
                Tab(
                    text: "達成"
                ),
                Tab(
                    text: "全て"
                )
              ]
          ),
        ),
        body: TabBarView(
          children: [
            TaskListComponent(tasks: allTasks.where((todo)=> !todo.done).toList()),
            TaskListComponent(tasks: allTasks.where((todo)=> todo.done).toList()),
            TaskListComponent(tasks: allTasks),

          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: (){
            return Navigator.pushNamed(context, "/create");
          },
        ),
      ),
      length: 3,
    );
  }
}

class TaskListComponent extends HookWidget {

  TaskListComponent({this.tasks});

  final List<Task> tasks;
  @override
  Widget build(BuildContext context) {
    final taskList = useProvider(taskListProvider);
    return Center(
      child: ListView.builder(itemBuilder: (context, index){
        return ListTile(
          title: Text(tasks[index].title),
          leading: Checkbox(value: tasks[index].done, onChanged: (b){
            taskList.toggleDone(tasks[index].id);
          }),
          onTap: (){
            taskList.toggleDone(tasks[index].id);
          },
          trailing: PopupMenuButton(
            child: Icon(Icons.more_vert),
            itemBuilder: (BuildContext context){
              return [
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      Text("編集")
                    ],
                  ),
                  value: 1
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      Text("削除"),
                    ]
                  ),
                  value: 2
                ),
              ];
            },
            onSelected: (int value){
              switch(value){
                case 1:
                  Navigator.pushNamed(context, "/create", arguments: TaskEditorPageArgs(taskId: tasks[index].id));
                  break;
                case 2:
                  showDialog(
                    context: context,
                    builder: (_){
                      return AlertConfirmTaskDeletion(taskId: tasks[index].id);
                    }
                  );
                  break;
              }
            },
          ),
        );
      }, itemCount: tasks.length),
    );
  }
}

class TaskEditorPageArgs {
  final String taskId;
  TaskEditorPageArgs({this.taskId});
}

class TaskEditorPage extends HookWidget {

  //final taskTitleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final taskList = useProvider(taskListProvider);
    final tasks = useProvider(taskListProvider.state);

    final TaskEditorPageArgs args = ModalRoute.of(context).settings.arguments;
    final taskId = useState<String>(args?.taskId);
    final text = useState<String>();
    final task = useState<Task>();

    if(args?.taskId != null){
      task.value = tasks.firstWhere((element) => element.id == args.taskId);

      text.value = task.value.title;
      //taskTitleEditingController.text = text.value;
    }
    final taskTitleEditingController = useTextEditingController(text: text.value ?? "");

    return Scaffold(
      appBar: AppBar(title: buildTitle(taskId.value)),
      body: Column(
        children: [

          TextField(
            controller: taskTitleEditingController,
            onChanged: (e){
              text.value = e;
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){
          if(task.value == null){
            taskList.create(taskTitleEditingController.text);
          }else{
            taskList.updateTitle(id: task.value.id, title: taskTitleEditingController.text);
          }
          Navigator.pop(context);
        },
        label: Text("保存"),
        icon: Icon(Icons.add)
      ),
    );
  }

  Widget buildTitle(String taskId) {
    if(taskId == null){
      return Text("作成");
    }else{
      return Text("編集");
    }
  }

}

class AlertConfirmTaskDeletion extends HookWidget {
  AlertConfirmTaskDeletion({this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final tl = useProvider(taskListProvider);

    return AlertDialog(
      title: Text("削除の確認"),
      content: Text("タスクを削除します。"),
      actions: [
        FlatButton(
          onPressed: (){
            Navigator.pop(context);
          },
          child: Text("キャンセル")
        ),
        FlatButton(
          onPressed: (){
            tl.delete(taskId);
            Navigator.pop(context);
          }, child: Text("削除する"))
      ]
    );
  }
}
