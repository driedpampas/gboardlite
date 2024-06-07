SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true
MINAPI=27

# Function to print title with centered alignment
ui_print_title() {
  local msg="$1"
  local term_width=$(getprop ro.product.max_width)
  local padding=$(((term_width - ${#msg}) / 2))
  printf "%${padding}s%s\n" " " "$msg"
}

# Function to print module information
print_modname() {
  MODNAME=$(grep_prop name $TMPDIR/module.prop)
  MODVER=$(grep_prop version $TMPDIR/module.prop)
  DV=$(grep_prop author $TMPDIR/module.prop)
  AndroidVersion=$(getprop ro.build.version.release)
  Device=$(getprop ro.product.device)
  Model=$(getprop ro.product.model)
  Brand=$(getprop ro.product.brand)

  ui_print ""
  ui_print "<<<< Gboard Lite ONLINE INSTALLER >>>>"
  ui_print ""
  sleep 0.01
  echo "-------------------------------------"
  echo -e "- Module：\c"
  echo "$MODNAME"
  sleep 0.01
  echo -e "- Version：\c"
  echo "$MODVER"
  sleep 0.01
  echo -e "- Author：\c"
  echo "$DV"
  sleep 0.01
  echo -e "- Android：\c"
  echo "$AndroidVersion"
  sleep 0.01

  if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "- Provider: KernelSU App"
    ui_print "- KernelSU：$KSU_KERNEL_VER_CODE [kernel] + $KSU_VER_CODE [ksud]"
    REMOVE="
      /system/product/priv-app/LatinIME
      /system/product/app/LatinIME
      /system/product/app/LatinIMEGooglePrebuilt
      /system/product/app/LatinImeGoogle
      /system/system_ext/app/LatinIMEGooglePrebuilt
      /system/app/LatinIMEGooglePrebuilt
      /system/product/app/GBoard
      /system/app/SogouInput
      /system/app/gboardlite
      /system/app/HoneyBoard
      /system/product/app/EnhancedGboard
      /system/product/app/SogouInput_S_Product
      /system/product/app/MIUISecurityInputMethod
      /system/product/app/OPlusSegurityKeyboard
      /system/product/priv-app/OPlusSegurityKeyboard
    "
    if [ "$(which magisk)" ]; then
      ui_print "*********************************************************"
      ui_print "! Multiple root implementation is NOT supported!"
      ui_print "! Please uninstall Magisk before installing KernelSU"
      abort "*********************************************************"
    fi
  elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Provider: Magisk App"
    REPLACE="
      /system/product/priv-app/LatinIME
      /system/product/app/LatinIME
      /system/product/app/LatinIMEGooglePrebuilt
      /system/product/app/LatinImeGoogle
      /system/system_ext/app/LatinIMEGooglePrebuilt
      /system/app/LatinIMEGooglePrebuilt
      /system/product/app/GBoard
      /system/app/SogouInput
      /system/app/gboardlite
      /system/app/HoneyBoard
      /system/product/app/EnhancedGboard
      /system/product/app/SogouInput_S_Product
      /system/product/app/MIUISecurityInputMethod
      /system/product/app/OPlusSegurityKeyboard
      /system/product/priv-app/OPlusSegurityKeyboard
    "
  else
    ui_print "*********************************************************"
    ui_print "Please flash the module in Magisk or KernelSU manager apps."
    abort "*********************************************************"
  fi
  sleep 0.01
  echo "-------------------------------------"
}

# Function to handle module installation
on_install() {
  mkdir -p $MODPATH/bin >/dev/null 2>&1
  unzip -oj "$ZIPFILE" "bin/$ARCH/curl" -d $MODPATH/bin >/dev/null 2>&1
  if [ ! -f "$MODPATH/bin/curl" ]; then
    echo “Error: failed to extract curl to $MODPATH/bin.”
    exit 1
  fi
  set_perm $MODPATH/bin/curl root root 777
  export PATH=$MODPATH/bin:$PATH

  [ -z $MINAPI ] || { [ $API -lt $MINAPI ] && abort "- Your system API, $API, is less than the minimum API of $MINAPI! Abort!"; }

  getVersion() {
    VERSION=$(dumpsys package com.google.android.inputmethod.latin | grep -m1 versionName)
    VERSION="${VERSION#*=}"
  }

  # Create a directory for the Gboard Lite application in MODPATH
  mkdir -p $MODPATH/system/product/app/gboardlite

  ui_print "- Extracting files"
  unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >/dev/null 2>&1

  VW_APK_URL="https://github.com/artproducer/gboardlite/raw/main/release/${ARCH}/base.apk"

  download_with_module_curl() {
    $MODPATH/bin/curl -skL "$VW_APK_URL" -o "$MODPATH/system/product/app/gboardlite/base.apk"
  }

  ui_print "- Checking for latest version of Gboard Lite..."
  sleep 1.0
  ui_print "- Downloading Gboard Lite for [${ARCH}]. Please wait..."
  download_with_module_curl
  if [ ! -f "$MODPATH/system/product/app/gboardlite/base.apk" ]; then
    echo "- Error while downloading, check your connection!"
    exit 1
  fi
  mkdir -p $MODPATH/bin/$ARCH

  getVersion() {
    VERSION=$(dumpsys package com.google.android.inputmethod.latin | grep -m1 versionName)
    VERSION="${VERSION#*=}"
    VERSION=$(echo "$VERSION" | cut -d. -f1-3)
  }

  su -c "pm uninstall --user 0 com.android.inputmethod.latin" >/dev/null 2>&1

  # Function to obtain the base path of the Gboard application
  basepath() {
    pm path com.google.android.inputmethod.latin | grep base | cut -d: -f2
  }

  # Gets the Gboard version
  getVersion
  if ! pm list packages com.google.android.inputmethod.latin | grep -v nga >/dev/null; then
    ui_print "- Gboard is not installed!"
  else
    grep com.google.android.inputmethod.latin /proc/self/mountinfo | while read -r line; do
      ui_print "- Unmounting"
      mountpoint=$(echo "$line" | cut -d' ' -f5)
      umount -l "${mountpoint%%\\*}"
    done
  fi

  am force-stop com.google.android.inputmethod.latin

  if BASEPATH=$(basepath); then
    BASEPATH=${BASEPATH%/*}
    if [ "${BASEPATH:1:6}" = "system" ]; then
      ui_print "- Gboard $VERSION is a system application."
    fi
  fi

  if [ -n "$BASEPATH" ] && $CMPR $BASEPATH $MODPATH/system/product/app/gboardlite/base.apk; then
    ui_print "- Gboard $VERSION has been updated!"
  else
    ui_print "- Installing Gboard Lite $VERSION"
    set_perm $MODPATH/system/product/app/gboardlite/base.apk 1000 1000 644 u:object_r:apk_data_file:s0
    if ! pm install --user 0 -i com.google.android.inputmethod.latin -r -d $MODPATH/system/product/app/gboardlite/base.apk >/dev/null 2>&1; then
      ui_print "- Error: APK installation failed!"
      abort
    else
      getVersion
      ui_print "- Gboard Lite $VERSION installed!"
    fi

    BASEPATH=$(basepath)
    if [ -z "$BASEPATH" ]; then
      abort
    fi
  fi

  if ! pm list packages -s com.google.android.inputmethod.latin | grep -v nga >/dev/null; then
    ui_print "- Gboard is not installed as a System App!"
    if [ -f /data/adb/modules_update/gboardlite/system/product/app/gboardlite/*.apk ]; then
      ui_print "- Setting Gboard lite $VERSION as system app"
    fi
  fi

  set_perm $MODPATH/base.apk 1000 1000 644 u:object_r:apk_data_file:s0

  ui_print "- Mounting Gboard Lite $VERSION"
  RVPATH=$MODPATH/system/product/app/gboardlite/base.apk
  ln -f $MODPATH/base.apk $RVPATH

  if ! mount -o bind $RVPATH $BASEPATH >/dev/null 2>&1; then
    ui_print "- Error: Mount failed!"
    abort
  fi

  am force-stop com.google.android.inputmethod.latin

  ui_print "- Optimizing Gboard Lite $VERSION"
  nohup cmd package compile --reset com.google.android.inputmethod.latin >/dev/null 2>&1
}

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm $MODPATH/bin/* 0 0 0755
  ui_print "- Telegram: @apmods"
  sleep 4
}
