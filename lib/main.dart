import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

final counterProvider = StateNotifierProvider((_)=> Counter());

final taskListProvider = StateNotifierProvider((_) => TaskList([Task(title: "hoge"), Task(title: "piyo"), Task(title: "fuga")]));

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
class Counter extends StateNotifier<int> {
  Counter() : super(0);
  void increment() => state ++;
}
void main() {
  runApp(ProviderScope(child: AppPage()));
}

class TaskList extends StateNotifier<List<Task>> {

  TaskList([List<Task> tasks]) : super(tasks ?? []);

  void add(String title) {
    final newTask = Task(title: title);
    this.state = [...this.state, newTask];
  }

  void toggleDone(String id) {
    this.state = [
      for(final task in this.state)
        if(task.id == id)
          Task(id: task.id, title: task.title, done: !task.done)
        else
          task
    ];
  }

  void delete(String id) {
    this.state = this.state.where((t)=> t.id != id);
  }


  void clear() {
    this.state = [];
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
        );
      }, itemCount: tasks.length),
    );
  }
}


class TaskEditorPage extends HookWidget {

  final taskTitleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final taskList = useProvider(taskListProvider);

    return Scaffold(
      appBar: AppBar(title: Text("作成"),),
      body: Column(
        children: [

          TextField(
            controller: taskTitleController,
            onChanged: (e){
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: (){
        taskList.add(taskTitleController.text);
        Navigator.pop(context);
      }, label: Text("作成"), icon: Icon(Icons.add)),
    );
  }
}

class CounterApp extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useProvider(counterProvider.state);
    final counter = useProvider(counterProvider);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('CounterApp')),
        body: Center(
          child: Text(state.toString())
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: ()=> counter.increment(),
          child: Icon(Icons.add),
        ),
      )
    );
  }
}
