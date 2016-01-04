//: Playground - noun: a place where people can play

import Cocoa
import simd
import Accelerate
import OpenGL
import OpenCL
import GLUT

func get_sys_info(name:String) -> Int64{
    var info:Int64 = 0
    var size = sizeof(Int64)
    if (sysctlbyname(name, &info, &size, nil, 0) < 0) { perror("sysctl") }
    return info
}

func get_sys_info(name:String) -> [uint8]{
    var size = 32
    var info = [uint8](count: size, repeatedValue: 0)
    if (sysctlbyname(name, &info, &size, nil, 0) < 0) { perror("sysctl") }
    return info
}

func get_cpu_freq() -> Int64 {
    return get_sys_info("hw.cpufrequency")
}

func get_mem_size() -> Int64 {
    return get_sys_info("hw.memsize")
}


let cpu  = get_cpu_freq()
let cpumodel = get_mem_size()

