import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";

class CourierSignupStep2Personal extends StatefulWidget { const CourierSignupStep2Personal({super.key}); @override State<CourierSignupStep2Personal> createState()=>_State(); }
class _State extends State<CourierSignupStep2Personal>{
 final name=TextEditingController(), phone=TextEditingController(), id=TextEditingController(); bool uploaded=false;
 @override void dispose(){name.dispose();phone.dispose();id.dispose();super.dispose();}
 Future<void> next() async{ if(name.text.trim().isEmpty||id.text.trim().isEmpty||!uploaded){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete personal details and ID upload.")));return;} await context.read<CourierSignupController>().submitStep2(fullName:name.text.trim(), idNumber:id.text.trim(), idImagePath:"placeholder-id.jpg");}
 @override Widget build(BuildContext context){ final loading=context.watch<CourierSignupController>().isLoading; return Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
  const Text("Personal Details",style:TextStyle(color:dropCitySafeSlate,fontSize:18,fontWeight:FontWeight.w800)), const SizedBox(height:8), const Text("Your ID is used for identity verification only.",style:TextStyle(color:dropCitySlateGrey,fontSize:11)), const SizedBox(height:18),
  TextField(controller:name,decoration:const InputDecoration(labelText:"Full Name",prefixIcon:Icon(Icons.person_outline))), const SizedBox(height:14),
  TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:"Phone Number",hintText:"+263 7X XXX XXXX",prefixIcon:Icon(Icons.phone_outlined))), const SizedBox(height:14),
  TextField(controller:id,decoration:const InputDecoration(labelText:"National ID Number",prefixIcon:Icon(Icons.badge_outlined))), const SizedBox(height:18),
  DashedUploadBox(label:"Upload National ID Photo",height:138,hasImage:uploaded,onTap:()=>setState(()=>uploaded=!uploaded)), const SizedBox(height:26), CourierPrimaryButton(label:"Continue ?",loading:loading,onPressed:next),
 ]);}}
