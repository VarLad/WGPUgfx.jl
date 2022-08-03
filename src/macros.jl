using WGPUgfx
using MacroTools

"""
Can take following format declarations

1. Builtin as datatype
expr = quote
	struct VertexInput
		a::@builtin position Int32
		b::@builtin vertex_index UInt32
	end
end

2. Builtin as attribute like in WGSL
expr = quote
	struct VertexInput
		@builtin position a::Vec4{Float32}
		@builtin vertex_index b::UInt32
		d::Float32
	end
end

3. Location


"""


"""
	struct VertexInput {
	    @builtin(vertex_index) vertex_index : u32,
	};

	struct VertexOutput {
	    @location(0) color : vec4<f32>,
	    @location(1) pos: vec4<f32>,
	};

	@stage(vertex)
	fn vs_main(in: VertexInput) -> VertexOutput {
	    var positions = array<vec2<f32>, 3>(
	    	vec2<f32>(0.0, -1.0),
	    	vec2<f32>(1.0, 1.0), 
	    	vec2<f32>(-1.0, 1.0)
	   	);
	    let index = i32(in.vertex_index);
	    let p: vec2<f32> = positions[index];

	    var out: VertexOutput;
	    out.pos = vec4<f32>(sin(p), 0.5, 1.0);
	    out.color = vec4<f32>(p, 0.5, 1.0);
	    return out;
	}

	@stage(fragment)
	fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
	    return in.color;
	}
"""
	

statements = false

expr = quote
	struct VertexInput
		@builtin vertex_index vi::UInt32
	end
	
	struct VertexOutput
		@location 0 color::Vec4{Float32}
		@location 1 pos::Vec4{Float32}
	end

	if $statements == true
		a = Int(0)
	end
	
	@vertex function vs_main()::Int32
	    index = 1
	    a = 2
	    b = 3
	end

	@fragment function fs_main()::Vec4{Float32}
		b = 200
	end

	function test(a::Int32, b::Float32)::Vec2{Float32}
		a::Int32 = 0
		b::Float32 = 3.0f0
		# c = 0
		test2()	
	end

	function test2()
	end
end


expr = MacroTools.striplines(expr)

dump(expr)

function wgslStruct(expr)
	expr = MacroTools.striplines(expr)
	expr = MacroTools.flatten(expr)
	@capture(expr, struct T_ fields__ end) || error("verify struct format of $T with fields $fields")
	fieldDict = Dict{Symbol, DataType}()
	for field in fields
		if @capture(field, name_::dtype_)
			fieldDict[name] = eval(dtype)
		elseif @capture(field, @builtin btype_ name_::dtype_)
			fieldDict[name] = eval(:(@builtin $btype $dtype))
		elseif @capture(field, @location btype_ name_::dtype_)
			fieldDict[name] = eval(:(@location $btype $dtype))
		end
	end
	makePaddedWGSLStruct(T, fieldDict)
end

function wgslAssignment(expr)
	io = IOBuffer()
	@capture(expr, a_ = b_) || error("Unexpected assignment!")
	@capture(a, arg_::type_) || error("Missing type information!")
	atype = wgslType(eval(type))
	write(io, "let $arg:$atype = $b\n")
	seek(io, 0)
	stmt = read(io, String)
	close(io)
	return stmt
end

function wgslVertex(expr)
	@capture(expr, @vertex function a__ end) || error("Expecting @vertex stage function!")
	return "@vertex fn $a"
end

function wgslFragment(expr)
	io = IOBuffer()
	@capture(expr, @fragment function a__ end) || error("Expecting @fragment stage function!")
	# fnCode = wgslFunction(a)
	return "@fragment $a"
end

function wgslFunction(expr)
	io = IOBuffer()
	@capture(expr, function fnbody__ end) || error("Expecting regular function!")
	if @capture(fnbody[1], fnname_(fnargs__)::fnout_)
		write(io, "fn $fnname(")
		len = length(fnargs)
		for (idx, arg) in enumerate(fnargs)
			if @capture(arg, aarg_::aatype_)
				intype = wgslType(eval(aatype))
				write(io, "$aarg:$(intype)"*(len==idx ? "" : ", "))
			end
			@capture(fnargs, aarg_) || error("Expecting type for function argument in WGSL!")
		end
		outtype = wgslType(eval(fnout))
		write(io, ") -> $outtype { \n")
		write(io, wgslCode(fnbody[2]))
	end
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end
# IOContext TODO
function wgslCode(expr)
	io = IOBuffer()
	expr = MacroTools.striplines(expr)
	expr = MacroTools.flatten(expr)
	@capture(expr, blocks__) || error("Current expression is not a quote or block")
	for block in blocks
		if @capture(block, struct T_ fields__ end)
			write(io, wgslStruct(block))
		elseif @capture(block, a_ = b_)
			write(io, wgslAssignment(block))
		elseif @capture(block, @vertex function a__ end)
			write(io, wgslVertex(block))
			write(io, "\n")
		elseif @capture(block, @fragment function a__ end)
			write(io, wgslFragment(block))
			write(io, "\n")
		elseif @capture(block, function a__ end)
			write(io, wgslFunction(block))
			write(io, "\n")
		elseif @capture(block, if cond_ ifblock_ end)
			if eval(cond) == true
				write(io, wgslCode(ifblock))
				write(io, "\n")
			end
		end
	end
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end

macro code_wgsl(expr)
	@eval expr
	a = wgslCode(eval(expr)) |> println
	return a
end

@code_wgsl expr