import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/google_sheet_api.dart';

class AddTransaction extends StatefulWidget {
  const AddTransaction({super.key});
  @override State<AddTransaction> createState()=>_AddState();
}

class _AddState extends State<AddTransaction> {
  final amount=TextEditingController(), to=TextEditingController(), notes=TextEditingController();
  String type='Paid', category='Others', bank='XXXXXXXX01', status='Completed';
  String mode='UPI';

  Future<void> save() async {
    final value=double.tryParse(amount.text.trim());
    if(value==null || value<=0 || to.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid amount and recipient')));
      return;
    }
    final now=DateTime.now();
    try {
      await GoogleSheetApi.addTransaction(TransactionModel(
        date:DateFormat('yyyy-MM-dd').format(now),
        time:DateFormat('h:mm:ss a').format(now),
        transaction:type,
        amount:value,
        to:to.text.trim(),
        bank:bank,
        status:status,
        category:category,
      ));
      if(mounted) Navigator.pop(context,true);
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Save failed: $e')));
    }
  }

  Widget drop(String label,String value,List<String> items,void Function(String?) onChanged)=>DropdownButtonFormField<String>(
    value:value, decoration:InputDecoration(labelText:label), items:items.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:onChanged);

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Add Transaction')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      drop('Type',type,['Paid','Received'],(v)=>setState(()=>type=v!)),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount')),
      TextField(controller:to,decoration:const InputDecoration(labelText:'To / From')),
      drop('Category',category,['Food','Travel','Bills','Shopping','Entertainment','Family','Health','Salary','Others'],(v)=>setState(()=>category=v!)),
      drop('Bank',bank,['XXXXXXXX01','XXXXXXXX02','XXXXXXXX03'],(v)=>setState(()=>bank=v!)),
      drop('Payment Mode',mode,['UPI','Cash','Card','Net Banking'],(v)=>setState(()=>mode=v!)),
      drop('Status',status,['Completed','Failed','Cancelled'],(v)=>setState(()=>status=v!)),
      TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Notes')),
      const SizedBox(height:20),
      FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('Save to Google Sheet')),
    ]),
  );
}
