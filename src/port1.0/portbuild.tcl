# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portbuild.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portbuild 1.0
package require portutil 1.0

set org.macports.build [target_new org.macports.build portbuild::build_main]
target_provides ${org.macports.build} build
target_requires ${org.macports.build} main fetch extract checksum patch configure
target_prerun ${org.macports.build} portbuild::build_start

namespace eval portbuild {
}

# define options
options build.target
options build.nice
options build.jobs
options build.asroot
options use_parallel_build
commands build
# defaults
default build.asroot no
default build.dir {${workpath}/${worksrcdir}}
default build.cmd {[portbuild::build_getmaketype]}
default build.nice {${buildnicevalue}}
default build.jobs {${buildmakejobs}}
default build.pre_args {${build.target}}
default build.target "all"
default use_parallel_build yes

set_ui_prefix

proc portbuild::build_getmaketype {args} {
    if {![exists build.type]} {
        return make
    }
    switch -exact -- [option build.type] {
        bsd {
            if {[option os.platform] == "darwin"} {
                return bsdmake
            } elseif {[option os.platform] == "freebsd"} {
                return make
            } else {
                return pmake
            }
        }
        gnu {
            if {[option os.platform] == "darwin"} {
                return gnumake
            } elseif {[option os.platform] == "linux"} {
                return make
            } else {
                return gmake
            }
        }
        pbx {
            set pbxbuild "pbxbuild"
            set xcodebuild "xcodebuild"
        
            if {[option os.platform] != "darwin"} {
                return -code error "[format [msgcat::mc "This port requires 'pbxbuild/xcodebuild', which is not available on %s."] [option os.platform]]"
            }
        
            if {[catch {set xcodebuild [binaryInPath $xcodebuild]}] == 0} {
                return $xcodebuild
            } elseif {[catch {set pbxbuild [binaryInPath $pbxbuild]}] == 0} {
                return $pbxbuild
            } else {
                return -code error "Neither pbxbuild nor xcodebuild were found on this system!"
            }
        }
        default {
            ui_warn "[format [msgcat::mc "Unknown build.type %s, using 'gnumake'"] [option build.type]]"
            return gnumake
        }
    }
}

proc portbuild::build_getnicevalue {args} {
    if {![exists build.nice] || [string match "* *" [option build.cmd]]} {
        return ""
    }
    set nice [option build.nice]
    if {![string is integer -strict $nice] || $nice <= 0} {
        return ""
    }
    return "nice -n $nice "
}

proc portbuild::build_getmakejobs {args} {
    # check if port allows a parallel build
    global use_parallel_build
    if {![tbool use_parallel_build]} {
        ui_debug "port disallows a parallel build"
        return ""
    }

    if {![exists build.jobs] || !([string match "*make*" [option build.cmd]] || [string match "*scons*" [option build.cmd]])} {
        return ""
    }
    set jobs [option build.jobs]
    # if set to '0', use the number of cores for the number of jobs
    if {$jobs == 0} {
        set jobs [exec "/usr/sbin/sysctl" "-n" "hw.ncpu"]
    }
    if {![string is integer -strict $jobs] || $jobs <= 1} {
        return ""
    }
    return " -j$jobs"
}

proc portbuild::build_start {args} {
    global UI_PREFIX build.asroot
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Building %s"] [option portname]]"
    
    # start gsoc08-privileges
    if { [tbool build.asroot] } {
	# if port is marked as needing root	
		elevateToRoot "build"
	}
	# end gsoc08-privileges
    
}

proc portbuild::build_main {args} {
    global build.cmd

    set nice_prefix [build_getnicevalue]
    set jobs_suffix [build_getmakejobs]

    set realcmd ${build.cmd}
    set build.cmd "$nice_prefix${build.cmd}$jobs_suffix"
    command_exec build
    set build.cmd ${realcmd}
    return 0
}
