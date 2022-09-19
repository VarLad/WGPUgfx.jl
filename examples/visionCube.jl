using Revise
using Debugger
using WGPUgfx
using WGPU
using WGPUNative
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPU.SetLogLevel(WGPU.WGPULogLevel_Debug)
canvas = WGPU.defaultCanvas(WGPU.WGPUCanvas);
gpuDevice = WGPU.getDefaultDevice();

camera = defaultVision()
light = defaultLighting()

scene = Scene(
	gpuDevice, 
	canvas, 
	camera, 
	light, 
	[], 
	repeat([nothing], 6)...
)

mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"))

addObject!(scene, mesh)

attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			runApp(gpuDevice, scene)
			PollEvents()
		end
	finally
		WGPU.destroyWindow(canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end