import 'package:dating_app/Auth/setup-screens/kids/kids.dart';
import 'package:dating_app/Auth/setup-screens/recordvideo/recordvideo.dart';
import 'package:dating_app/Dashbaord/search/search.dart';
import 'package:get/get.dart';
import 'package:dating_app/Auth/welcomescreen/splashscreen.dart';
import 'package:dating_app/Auth/welcomescreen/welcomescreen.dart';
import 'package:dating_app/Auth/Loginwithphone/loginwithphone.dart';
import 'package:dating_app/Auth/Loginwithemail/loginwithemail.dart';
import 'package:dating_app/Auth/Reset/Resetyourpassword/Resetyourpassword.dart';
import 'package:dating_app/Auth/Reset/setnewpassword/Setnewpassword.dart';
import 'package:dating_app/Dashbaord/dashboard/Dashboard.dart';
import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairup.dart';
import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairupdetailscreen/pairupdetailscreen.dart';

import '../Auth/Signupfromphone/SignupWithphone.dart';
import '../Auth/setup-screens/Age/age.dart';
import '../Auth/setup-screens/aboutme/Aboutme.dart';
import '../Auth/setup-screens/attachment/attachment.dart';
import '../Auth/setup-screens/bondingmoments/bondingmoments.dart';
import '../Auth/setup-screens/enterpassword/EnterPassword.dart';
import '../Auth/setup-screens/gettoknow/gettoknow.dart';
import '../Auth/setup-screens/height/height.dart';
import '../Auth/setup-screens/interestedIn/interestedIn.dart';
import '../Auth/setup-screens/location/location.dart';
import '../Auth/setup-screens/lovelanguage/lovelanguage.dart';
import '../Auth/setup-screens/personaldetails/Personaldetails.dart';
import '../Auth/setup-screens/pets/pets.dart';
import '../Auth/setup-screens/relationshipgoal/Relationshipgoal.dart';
import '../Auth/setup-screens/relocate/relocate.dart';
import '../Auth/setup-screens/socialcirclephoto/socialcirclephoto.dart';
import '../Auth/setup-screens/uploadphotos/uploadphotos.dart';
import '../Auth/setup-screens/yourhabbits/yourhabbits.dart';

class AppRoutes {
  static const String splashscreen = '/SplashScreen';
  static const String welcome = '/';
  static const String loginPhone = '/loginPhone';
  static const String loginEmail = '/loginEmail';
  static const String signupPhone = '/signupPhone';
  static const String resetPassword = '/reset-password';
  static const String setNewPassword = '/setnewpassword';
  static const String enterNumber = '/enternumber';
  static const String enterPassword = '/EnterPassword';
  static const String profileDetails = '/ProfileDetails';
  static const String height = '/height';
  static const String interestedIn = '/interestedin';
  static const String uploadPhoto = '/uploadphoto';
  static const String socialCircle = '/socialcircle';
  static const String bonding = '/bonding';
  static const String aboutMe = '/aboutme';
  static const String relationshipGoal = '/Relationshipgoal';
  static const String pets = '/pets';
  static const String habits = '/yourhabbit';
  static const String loveLanguage = '/lovelanguage';
  static const String attachment = '/attachment';
  static const String relocate = '/relocate';
  static const String dashboard = '/dashboard';
  static const String location = '/location';
  static const String getToKnow = '/gettoknow';
  static const String age = '/age';
  static const String pairUp = '/pairupscreens';
  static const String eventDetails = '/EventDetailsScreen';
  static const String socialConnections = '/social-connections';
  static const String recordvideo= '/recordvideo';
  static const String socialmedia= '/socialmedia';
  // static const String kids='/kids';
  static const String searchscreen ='/searchscreen';

  static final List<GetPage> routes = [
    GetPage(name: searchscreen, page: () => SearchScreen()),
    GetPage(name: splashscreen, page: () => SplashScreen()),
    // GetPage(name: kids, page: () => KidsSetupScreen()),
    GetPage(name: welcome, page: () => const WelcomeScreen()),
    GetPage(name: loginPhone, page: () => const LoginWithPhoneScreen()),
    GetPage(name: loginEmail, page: () => LoginWithEmailScreen()),
    GetPage(name: signupPhone, page: () => const SignUpWithPhoneScreen()),
    GetPage(name: resetPassword, page: () => const Resetyourpassword()),
    GetPage(name: setNewPassword, page: () => const SetNewPassword()),
    GetPage(name: enterPassword, page: () => const EnterPassword()),
    GetPage(name: profileDetails, page: () => const ProfileDetails()),
    GetPage(name: height, page: () => const HeightSelection()),
    GetPage(name: interestedIn, page: () => InterestedInScreen()),
    GetPage(name: uploadPhoto, page: () => UploadYourPhotosScreen()),
    GetPage(name: socialCircle, page: () => SocialCirclePhotoScreen()),
    GetPage(name: bonding, page: () => const BondingMomentsScreen()),
    GetPage(name: aboutMe, page: () => const AboutMeScreen()),
    GetPage(name: relationshipGoal, page: () => const Relationshipgoal()),
    GetPage(name: pets, page: () => const PetsSelectionScreen()),
    GetPage(name: habits, page: () => GetToKnowYourHabitsScreen()), // ✅ FIXED
    GetPage(name: loveLanguage, page: () => const LoveLanguagesScreen()),
    GetPage(name: attachment, page: () => const AttachmentsScreen()),
    GetPage(name: relocate, page: () => const RelocateLoveScreen()),
    GetPage(name: dashboard, page: () => const DashboardScreen()),
    GetPage(name: location, page: () => PairUpLocationScreen()),
    GetPage(name: getToKnow, page: () => GetToKnowMeScreen()),
    GetPage(name: enterNumber, page: () => LoginWithPhoneScreen()),
    GetPage(name: age, page: () => AgeSelection()),
    GetPage(name: pairUp, page: () => PairUp()),
    GetPage(name: recordvideo, page: ()=> RecordVideoScreen()),
    GetPage(
      name: eventDetails,
      page: () => EventDetailsScreen(event: {}),
    ),
  ];
}
