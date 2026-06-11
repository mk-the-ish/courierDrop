import "package:flutter/material.dart";
import "package:provider/provider.dart";
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourierSignupStep4Vehicle extends StatefulWidget { const CourierSignupStep4Vehicle({super.key}); @override State<CourierSignupStep4Vehicle> createState()=>_State(); }
class _State extends State<CourierSignupStep4Vehicle>{
 final make=TextEditingController(), model=TextEditingController(), year=TextEditingController(), color=TextEditingController(), reg=TextEditingController(), cap=TextEditingController();
 final List<String> _keys = ["Front","Side","Rear","Interior"];
 final Map<String,String?> _photoPaths = {"Front":null,"Side":null,"Rear":null,"Interior":null};
 final ImagePicker _picker = ImagePicker();

 @override void dispose(){make.dispose();model.dispose();year.dispose();color.dispose();reg.dispose();cap.dispose();super.dispose();}

 @override void initState(){ super.initState(); _restoreSavedPhotos(); }

 Future<void> _restoreSavedPhotos() async{
     try{
         final prefs = await SharedPreferences.getInstance();
         for(final k in _keys){ final p = prefs.getString('signup_step4_$k'); if(p!=null && File(p).existsSync()) _photoPaths[k]=p; }
         setState((){});
     }catch(_){ }
 }

 Future<void> _pickForKey(String key, {bool fromGallery=false}) async{
     try{
         final src = fromGallery?ImageSource.gallery:ImageSource.camera;
         final XFile? file = await _picker.pickImage(source: src, maxWidth:1600, imageQuality:85);
         if(file==null) return;
         final p = file.path;
         final prefs = await SharedPreferences.getInstance();
         await prefs.setString('signup_step4_$key', p);
         setState(()=> _photoPaths[key]=p);
     }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e'))); }
 }

 Future<void> _removeForKey(String key) async{
     try{ final prefs = await SharedPreferences.getInstance(); await prefs.remove('signup_step4_$key'); }catch(_){ }
     setState(()=> _photoPaths[key]=null);
 }

 Future<void> _showOptionsForKey(String key) async{
        await showModalBottomSheet<void>(
            context: context,
            builder: (ctx) => SafeArea(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Take Photo'),
                            onTap: () {
                                Navigator.of(ctx).pop();
                                _pickForKey(key);
                            },
                        ),
                        ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose From Gallery'),
                            onTap: () {
                                Navigator.of(ctx).pop();
                                _pickForKey(key, fromGallery: true);
                            },
                        ),
                        if (_photoPaths[key] != null)
                            ListTile(
                                leading: const Icon(Icons.refresh),
                                title: const Text('Retake / Replace Photo'),
                                onTap: () {
                                    Navigator.of(ctx).pop();
                                    _pickForKey(key);
                                },
                            ),
                        if (_photoPaths[key] != null)
                            ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('Remove Photo'),
                                onTap: () {
                                    Navigator.of(ctx).pop();
                                    _removeForKey(key);
                                },
                            ),
                        ListTile(
                            leading: const Icon(Icons.close),
                            title: const Text('Cancel'),
                            onTap: () => Navigator.of(ctx).pop(),
                        ),
                    ],
                ),
            ),
        );
    }

 Future<void> submit() async{ if([make,model,year,color,reg,cap].any((c)=>c.text.trim().isEmpty)|| _keys.any((k)=>_photoPaths[k]==null)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete vehicle details and all four photos.")));return;} await context.read<CourierSignupController>().submitStep4(vehicleData:{"vehicle_make":make.text,"vehicle_model":model.text,"vehicle_year":int.tryParse(year.text)??2026,"vehicle_color":color.text,"vehicle_registration":reg.text,"vehicle_capacity_kg":double.tryParse(cap.text)??20,"vehicle_type":"car"},vehicleImagePaths: _keys.map((k)=>_photoPaths[k] ?? "").toList());}

 @override Widget build(BuildContext context){ final loading=context.watch<CourierSignupController>().isLoading; return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text("Your Vehicle",style:TextStyle(color:dropCitySafeSlate,fontSize:18,fontWeight:FontWeight.w800)), const SizedBox(height:8), const Text("Your vehicle will be reviewed by DropCity admin before your first delivery.",style:TextStyle(color:dropCitySlateGrey,fontSize:11,fontStyle:FontStyle.italic)), const SizedBox(height:18),
    TextField(controller:make,decoration:const InputDecoration(labelText:"Vehicle Make")), const SizedBox(height:12), TextField(controller:model,decoration:const InputDecoration(labelText:"Model")), const SizedBox(height:12),
    Row(children:[Expanded(child:TextField(controller:year,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:"Year"))), const SizedBox(width:12), Expanded(child:TextField(controller:color,decoration:const InputDecoration(labelText:"Colour")))]), const SizedBox(height:12),
    TextField(controller:reg,decoration:const InputDecoration(labelText:"Registration Number")), const SizedBox(height:12), TextField(controller:cap,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:"Capacity",suffixText:"kg")), const SizedBox(height:18),
    GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1.15,children:_keys.map((k)=>DashedUploadBox(label:k,hasImage:_photoPaths[k]!=null,imagePath:_photoPaths[k],onTap:()=>_showOptionsForKey(k))).toList()), const SizedBox(height:24), CourierPrimaryButton(label:"Submit for Approval",loading:loading,onPressed:submit),
 ]);} 

}
