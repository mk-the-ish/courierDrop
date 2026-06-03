import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";

class CourierSignupStep3License extends StatefulWidget { const CourierSignupStep3License({super.key}); @override State<CourierSignupStep3License> createState()=>_State(); }
class _State extends State<CourierSignupStep3License>{
 final licence=TextEditingController(); bool front=false, back=false; DateTime? expiry;
 @override void dispose(){licence.dispose();super.dispose();}
 Future<void> next() async{ if(licence.text.trim().isEmpty||!front||!back){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Licence number plus both photos are required.")));return;} await context.read<CourierSignupController>().submitStep3(licenseNumber:licence.text.trim(), licenseImagePath:"placeholder-license.jpg");}
 @override Widget build(BuildContext context){ final loading=context.watch<CourierSignupController>().isLoading; return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text("Driver's Licence",style:TextStyle(color:dropCitySafeSlate,fontSize:18,fontWeight:FontWeight.w800)), const SizedBox(height:18),
  TextField(controller:licence,decoration:const InputDecoration(labelText:"Licence Number",prefixIcon:Icon(Icons.credit_card))), const SizedBox(height:18),
  Row(children:[Expanded(child:DashedUploadBox(label:"Front of Licence",height:112,hasImage:front,onTap:()=>setState(()=>front=!front))), const SizedBox(width:12), Expanded(child:DashedUploadBox(label:"Back of Licence",height:112,hasImage:back,onTap:()=>setState(()=>back=!back)))]), const SizedBox(height:14),
  ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month,color:dropCityTransitTeal),title:Text(expiry==null?"Expiry Date":expiry!.toIso8601String().split("T").first),onTap:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime(2045),initialDate:DateTime.now().add(const Duration(days:365))); if(d!=null)setState(()=>expiry=d);}),
  const SizedBox(height:22), CourierPrimaryButton(label:"Continue ?",loading:loading,onPressed:next),
 ]);}}
