import "package:flutter/material.dart";
import "../auth/auth_state.dart";
import "../theme.dart";
import "assigned_parcels_screen.dart";
import "courier_dashboard_screen.dart";
import "route_declaration_screen.dart";
import "settings_screen.dart";

class NavigationHubScreen extends StatefulWidget{const NavigationHubScreen({super.key,required this.authState});final AuthState authState;@override State<NavigationHubScreen> createState()=>_State();}
class _State extends State<NavigationHubScreen>{int index=0; late final screens=[CourierDashboardScreen(authState:widget.authState),RouteDeclarationScreen(authState:widget.authState),AssignedParcelsScreen(authState:widget.authState),SettingsScreen(authState:widget.authState)];
@override Widget build(BuildContext context)=>WillPopScope(onWillPop:()async=>false,child:Scaffold(body:IndexedStack(index:index,children:screens),bottomNavigationBar:Container(decoration:BoxDecoration(color:dropCityCloudWhite,border:Border(top:BorderSide(color:dropCitySlateGrey.withOpacity(.25)))),child:SafeArea(top:false,child:BottomNavigationBar(currentIndex:index,onTap:(v)=>setState(()=>index=v),type:BottomNavigationBarType.fixed,backgroundColor:dropCityCloudWhite,elevation:0,selectedItemColor:dropCitySafeSlate,unselectedItemColor:dropCitySlateGrey,items:const [BottomNavigationBarItem(icon:Icon(Icons.home_outlined),activeIcon:Icon(Icons.home),label:"Home"),BottomNavigationBarItem(icon:Icon(Icons.route_outlined),activeIcon:Icon(Icons.route),label:"Routes"),BottomNavigationBarItem(icon:Badge(label:Text("2"),child:Icon(Icons.inventory_2_outlined)),activeIcon:Icon(Icons.inventory_2),label:"Parcels"),BottomNavigationBarItem(icon:Icon(Icons.settings_outlined),activeIcon:Icon(Icons.settings),label:"Settings")])))));}
