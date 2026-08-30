import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';
import 'add_transaction.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState()=>_DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<TransactionModel> rows=[];
  bool loading=true;
  String? error;

  Future<void> load() async {
    setState(()=>loading=true);
    try {
      final r=await GoogleSheetApi.getTransactions();
      setState(()=>rows=r);
    } catch(e) {
      setState(()=>error=e.toString());
    } finally {
      setState(()=>loading=false);
    }
  }

  @override void initState(){super.initState();load();}

  @override Widget build(BuildContext context) {
    final expense=rows.where((x)=>x.status=='Completed' && x.transaction.toLowerCase()=='paid')
      .fold(0.0,(s,x)=>s+x.amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Tracker'),
        actions:[IconButton(onPressed:load,icon:const Icon(Icons.sync))],
      ),
      floatingActionButton:FloatingActionButton(
        onPressed:() async {
          final ok=await Navigator.push(context,MaterialPageRoute(builder:(_)=>const AddTransaction()));
          if(ok==true) load();
        },
        child:const Icon(Icons.add),
      ),
      body:loading
        ? const Center(child:CircularProgressIndicator())
        : error!=null
          ? Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
              mainAxisSize:MainAxisSize.min,
              children:[Text(error!,textAlign:TextAlign.center),const SizedBox(height:12),
              ElevatedButton(onPressed:load,child:const Text('Retry'))])))
          : RefreshIndicator(
            onRefresh:load,
            child:ListView(padding:const EdgeInsets.all(16),children:[
              Card(child:ListTile(title:const Text('Completed Paid Amount'),subtitle:Text('${rows.length} transactions'),trailing:Text('₹${expense.toStringAsFixed(2)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))),
              const SizedBox(height:8),
              ...rows.reversed.take(20).map((x)=>Card(child:ListTile(
                title:Text(x.to.isEmpty?'Unknown':x.to),
                subtitle:Text('${x.date} ${x.time}\n${x.category} · ${x.status}'),
                isThreeLine:true,
                trailing:Text('₹${x.amount.toStringAsFixed(2)}'),
              )))
            ]),
          ),
    );
  }
}
