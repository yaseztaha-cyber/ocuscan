# OcuScan release keep rules.
#
# Root cause of the v0.7.9/v0.7.10 detector NPE (CPH2121, Android 12):
# R8 stripped the static fields of ML Kit's Dynamite local-module
# descriptor. DynamiteModule.getLocalVersion() reads MODULE_ID /
# MODULE_VERSION of
#   com.google.android.gms.dynamite.descriptors.com.google.mlkit.dynamite.face.ModuleDescriptor
# by reflection and returns 0 when the fields are missing. A local
# version of 0 makes ML Kit skip the BUNDLED (thick, offline) face module
# and fall back to the downloadable Play-services (thin) module, whose
# remote implementation threw the NullPointerException on the device.
# Keeping the descriptor + thick creator forces the bundled offline path.

# Dynamite local-module descriptor: class name AND static fields are read
# reflectively. Keep everything.
-keep class com.google.android.gms.dynamite.descriptors.com.google.mlkit.dynamite.face.ModuleDescriptor {
    *;
}

# Thick (bundled) detector creator, instantiated by class name through
# DynamiteModule.instantiate(). Keep the name and members.
-keep class com.google.mlkit.vision.face.bundled.internal.ThickFaceDetectorCreator {
    *;
}

# Firebase-component registrars / init provider, discovered via the app
# manifest + reflection during MlKitContext init. Pin explicitly so a
# future R8/AGP upgrade cannot drop them.
-keep class com.google.mlkit.common.internal.MlKitInitProvider {
    *;
}
-keep class com.google.mlkit.common.internal.CommonComponentRegistrar {
    *;
}
-keep class com.google.mlkit.vision.common.internal.VisionCommonRegistrar {
    *;
}
-keep class com.google.mlkit.vision.face.internal.FaceRegistrar {
    *;
}
