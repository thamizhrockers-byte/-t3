import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';
import 'add_transaction.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  List<TransactionModel> rows = [];
  bool loading = true;
  String? error;

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final r = await GoogleSheetApi.getTransactions();

      setState(() {
        rows = r;
        error = null;
      });

    } catch(e) {
      setState(() => error = e.toString());
    }
    finally {
      setState(() => loading = false);
    }
  }


  @override
  void initState(){
    super.initState();
    load();
  }


  Map<String,double> get categoryData {

    final map=<String,double>{};

    for(final x in rows){

      if(x.transaction.toLowerCase()=="paid"){

        map[x.category]=
          (map[x.category] ?? 0)+x.amount;

      }

    }

    return map;
  }



  @override
  Widget build(BuildContext context){

    final expense =
      rows
      .where((x)=>
        x.transaction.toLowerCase()=="paid")
      .fold(0.0,(s,x)=>s+x.amount);


    return Scaffold(

      appBar: AppBar(
        title:const Text("Money Tracker"),
        actions:[
          IconButton(
            onPressed:load,
            icon:const Icon(Icons.sync)
          )
        ],
      ),


      floatingActionButton:FloatingActionButton(
        onPressed:() async{

          final ok=await Navigator.push(
            context,
            MaterialPageRoute(
              builder:(_)=>const AddTransaction()
            )
          );

          if(ok==true) load();

        },
        child:const Icon(Icons.add),
      ),



      body:loading

      ?const Center(
        child:CircularProgressIndicator()
      )


      :error!=null

      ?Center(
        child:Text(error!)
      )


      :RefreshIndicator(

        onRefresh:load,

        child:ListView(

          padding:const EdgeInsets.all(16),

          children:[


            Card(
              child:ListTile(
                title:
                const Text(
                  "Total Expense"
                ),

                subtitle:
                Text(
                  "${rows.length} transactions"
                ),

                trailing:
                Text(
                  "₹${expense.toStringAsFixed(2)}",
                  style:
                  const TextStyle(
                    fontSize:20,
                    fontWeight:FontWeight.bold
                  ),
                ),
              ),
            ),



            const SizedBox(height:20),



            if(categoryData.isNotEmpty)

            Card(

              child:SizedBox(

                height:300,

                child:PieChart(

                  PieChartData(

                    sections:

                    categoryData.entries.map((e){

                      return PieChartSectionData(

                        value:e.value,

                        title:
                        "${e.key}\n₹${e.value.toInt()}",

                        radius:80,

                      );

                    }).toList(),

                  ),

                ),

              ),

            ),



            const SizedBox(height:20),


            const Text(
              "Recent Transactions",
              style:
              TextStyle(
                fontSize:18,
                fontWeight:FontWeight.bold
              ),
            ),



            ...rows.reversed.take(20).map(

              (x)=>Card(

                child:ListTile(

                  title:
                  Text(
                    x.to.isEmpty
                    ?"Unknown"
                    :x.to
                  ),

                  subtitle:
                  Text(
                    "${x.date} ${x.time}\n${x.category} · ${x.status}"
                  ),

                  isThreeLine:true,


                  trailing:
                  Text(
                    "₹${x.amount.toStringAsFixed(2)}"
                  ),

                ),

              )

            )

          ],

        ),

      ),

    );

  }

}
