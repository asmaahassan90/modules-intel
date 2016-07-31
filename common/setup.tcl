#%Module 1.0 -*- tcl -*-

# Set some global variables that we need here and in the module file including this one.
set ::module_name [lrange [split [module-info name] /] 0 0]
set ::module_name_uc [string toupper $::module_name]
set ::module_name_lc [string tolower $::module_name]
set ::version [lrange [split [module-info name] /] 1 1]
set ::module_build [file tail [module-info name]]
set ::distro $::env(KAUST_DISTRO)
set ::distro_fb el6
set ::m_arch $::env(KAUST_ARCH)
set curpath [file dirname $::ModulesCurrentModulefile]
set ::module_extra_dir [regsub {/(applications|compilers|libs)/} $curpath {/\1-extra/}]
set ::dir_name $::module_name

proc getDirName { appsroot appname } {
    set dirlist [glob -nocomplain -directory $appsroot -tails *]
    return [lsearch -inline -nocase [split $dirlist] $appname]
}

proc checkLicense {} {
    global module_extra_dir

    if [file exists "$module_extra_dir/.nolicense"] {
       puts stderr "\033\[7;31;31m"
       puts stderr "License has expired!"
       puts stderr ""
       puts stderr "* For more information, please contact IT Software Solutions Office:"
       puts stderr ""
       puts stderr "\tsso@kaust.edu.sa"
       puts stderr "\033\[m"
       exit 1
    }
}

proc SetAppDir { suffix_dir { app_dir_env 0 } } {
    #KAUST APPNAME
    regsub -all {[\-]} ${::module_name_uc} "_" KAUST_APPNAME
    setenv KAUST_APPNAME ${KAUST_APPNAME}

    if { $app_dir_env == 0 } {
        set app_dir_env ${KAUST_APPNAME}_ROOT
    }

    # app_root
    if { [info exists ::env(KAUST_APPS_ROOT)] } {
       set ::apps_root $::env(KAUST_APPS_ROOT)
    } else {
       set ::apps_root /opt/share
    }

    set ::dir_name [getDirName $::apps_root $::dir_name]

    # app_dir
    if { [info exists ::env(${app_dir_env})] } {
       set ::app_dir $::env(${app_dir_env})
    } else {
       set ::app_dir $::apps_root/$::dir_name/$suffix_dir

       #Do we need to fallback
       if { [file exists $::app_dir] == 0 } {
            set ::app_dir [string map "/$::distro /$::distro_fb" $::app_dir]
        }
    }

    # out of the if-stm, to be shown on "module show"
    setenv ${app_dir_env} $::app_dir
}

proc GeneralModulesHelp {} {
    puts stderr "\tThis module loads $::module_name version $::version\n"
}

proc SetWhatis {} {
    global module_extra_dir
    global desc_file

    set desc_file [join [read [open "$module_extra_dir/.desc"]]]
    module-whatis "$desc_file"
}

proc ReportModuleUsage {} {
    global loading
    global unloading

    set loading [module-info mode load]
    set unloading [module-info mode remove]

    switch [module-info mode] {
        load {
            puts stderr "Loading module $::module_name version $::version"
        }
        remove {
            puts stderr "Unloading module $::module_name version $::version"
        }
    }
}

proc ReportIntelVersion {} {
    global current_version
    if {[catch {set current_version [exec $::module_name --version | head -n1 | awk "{ print \$3 }" ]} e]} {
        set current_version none
    }

    puts stderr "Current $::module_name version: $current_version"
}

proc GeneralAppSetup { { suffix_dir 0 } { app_dir_env 0 } } {
    proc ModulesHelp { } {
        GeneralModulesHelp
    }

    # Set defualt suffix_dir to Version/Build, e.g. 5.5.1/openmpi2.3.0-gcc4.9.0
    if { $suffix_dir == 0 } {
        set comparison [string compare ${::version} ${::module_build}]
        if {$comparison == 0} {
            set suffix_dir ${::version}
        } else {
            set suffix_dir ${::version}/${::module_build}
        }
    }

    SetAppDir $suffix_dir $app_dir_env

    SetWhatis

    ReportModuleUsage

    conflict $::module_name
}

proc GeneralCompilerSetup { { suffix_dir 0 } { app_dir_env 0 } } {
    if { $suffix_dir == 0 } { set suffix_dir ${::version} }
    GeneralAppSetup $suffix_dir $app_dir_env
}

proc GeneralLibSetup { { suffix_dir 0 } { app_dir_env 0 } } {
    if { $suffix_dir == 0 } { set suffix_dir ${::version} }
    GeneralAppSetup $suffix_dir $app_dir_env
}

proc AddDeps { csv_list } {
    # Process dependancies
    set modules_to_load [split $csv_list ","]
    foreach line $modules_to_load {
        if {$line != ""} {
            set line [string trim $line]
            if ![is-loaded $line] {
                module add $line
            }
        }
    }
}


proc isnoor1 {} {

  if {[catch {exec grep -q "6\.2" /etc/redhat-release && true} isnoor1]} {
    #puts stderr "not redhat 6.2"
    if {[exec hostname] == "rcfen06" || [exec hostname] == "rcfen05"} {
      return 1
     }
    return 0
  } else {
    #puts stderr "redhat 6.2"
    return 1
  }

 

}




proc AddDepsBasedOnCompiler {} {
    # Load compiler based on module build
    set module_to_load [string map {- /} $::module_build]

    AddDeps "$module_to_load"
}



proc AddDepsBasedOnMpiCompiler {} {
    # Load compiler based on module build
    # Find last dash in the string
    set last_dash_index [expr [string last - $::module_build] - 1]
    # Get substring containing first two dashes
    set substring [string range $::module_build 0 $last_dash_index]
    set middle_dash_index [expr [string last - $substring] - 1]
    # Extract MPI library/compiler from module build
    set mpi [string range $::module_build 0 $middle_dash_index]
    # Extract compiler from module build. We have to readd offsets we took off before
    set compiler [string range $::module_build [expr $middle_dash_index + 2] end]
    set module_to_load [string map {- /} $mpi]/$compiler

    AddDeps "$module_to_load"
}

checkLicense
