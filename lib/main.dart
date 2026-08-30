import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main()=>runApp(const MoneyTrackerApp());

class MoneyTrackerApp extends StatelessWidget{
 const MoneyTrackerApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(
  debugShowCheckedModeBanner:false,
  title:'Money Tracker',
  theme:ThemeData(colorSchemeSeed:Colors.indigo,useMaterial3:true),
  home:const Dashboard(),
 );
}
