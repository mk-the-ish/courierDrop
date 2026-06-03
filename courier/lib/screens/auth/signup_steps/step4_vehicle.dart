import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";

class CourierSignupStep4Vehicle extends StatefulWidget { const CourierSignupStep4Vehicle({super.key}); @override State<CourierSignupStep4Vehicle> createState()=>_State(); }
class _State extends State<CourierSignupStep4Vehicle>{
 final make=TextEditingController(), model=TextEditingController(), year=TextEditingController(), color=TextEditingController(), reg=TextEditingController(), cap=TextEditingController(); final photos=<String,bool>{"Front":false,"Side":false,"Rear":false,"Interior":false};
 @override void dispose(){make.dispose();model.dispose();year.dispose();color.dispose();reg.dispose();cap.dispose();super.dispose();}
 Future<void> submit() async{ if([make,model,year,color,reg,cap].any((c)=>c.text.trim().isEmpty)||photos.values.any((v)=>!v)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete vehicle details and all four photos.")));return;} await context.read<CourierSignupController>().submitStep4(vehicleData:{"vehicle_make":make.text,"vehicle_model":model.text,"vehicle_year":int.tryParse(year.text)??2026,"vehicle_color":color.text,"vehicle_registration":reg.text,"vehicle_capacity_kg":double.tryParse(cap.text)??20,"vehicle_type":"car"},vehicleImagePaths:List.filled(4,"placeholder-vehicle.jpg"));}
 @override Widget build(BuildContext context){ final loading=context.watch<CourierSignupController>().isLoading; return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text("Your Vehicle",style:TextStyle(color:dropCitySafeSlate,fontSize:18,fontWeight:FontWeight.w800)), const SizedBox(height:8), const Text("Your vehicle will be reviewed by DropCity admin before your first delivery.",style:TextStyle(color:dropCitySlateGrey,fontSize:11,fontStyle:FontStyle.italic)), const SizedBox(height:18),
  TextField(controller:make,decoration:const InputDecoration(labelText:"Vehicle Make")), const SizedBox(height:12), TextField(controller:model,decoration:const InputDecoration(labelText:"Model")), const SizedBox(height:12),
  Row(children:[Expanded(child:TextField(controller:year,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:"Year"))), const SizedBox(width:12), Expanded(child:TextField(controller:color,decoration:const InputDecoration(labelText:"Colour")))]), const SizedBox(height:12),
  TextField(controller:reg,decoration:const InputDecoration(labelText:"Registration Number")), const SizedBox(height:12), TextField(controller:cap,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:"Capacity",suffixText:"kg")), const SizedBox(height:18),
  GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1.15,children:photos.keys.map((k)=>DashedUploadBox(label:k,hasImage:photos[k]!,onTap:()=>setState(()=>photos[k]=!photos[k]!))).toList()), const SizedBox(height:24), CourierPrimaryButton(label:"Submit for Approval",loading:loading,onPressed:submit),
 ]);}}
