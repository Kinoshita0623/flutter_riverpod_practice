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

  void create(String title) {
    final newTask = Task(title: title);
    this.state = [...this.state, newTask];
  }
  
  void updateTitle({String id, String title}) {
    this.state = [
      for(final task in this.state)
        if(task.id == id)
          Task(
            id: id,
            title: title,
            done: task.done
          )
        else
          task
    ];
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
    this.state = this.state.where((t)=> t.id != id).toList();
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
