// Get the canvas element and its context
import * as utils from "./utils.js";
import * as perlin from "./perlin.js";
const canvas = document.getElementById("canvas");
const IMAGE_SIZE = 1024;
const WORKGROUP_SIZE = 16;
const CENTER = [IMAGE_SIZE/2, IMAGE_SIZE/2];

async function initWebGPU() {
    

    // Check if WebGPU is supported
    if (!navigator.gpu) {
        throw new Error("WebGPU not supported on this browser.");
    }

    // Request a GPU adapter and device
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) {
        throw new Error("No appropriate GPUAdapter found.");
    }
    const device = await adapter.requestDevice();

    // Configure the context format
    const context = canvas.getContext('webgpu');
    const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
        device: device,
        format: canvasFormat
    });

    /* Set Up Bindgroup */
    const bindGroupLayout = device.createBindGroupLayout({
        label: "Bind Group Layout",
        entries: [{
            binding: 0,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: {} // Grid uniform buffer
        }, {
            binding: 1,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE ,
            buffer: { type: "storage" } // Cell state output buffer
        }, {
            binding: 2,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: {} // Time buffer
        }, {
            binding: 3,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: { type: "read-only-storage" } // Map buffer
        }, {
            binding: 4,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: {} // Ocean buffer
        }, {
            binding: 5,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: {} // Light buffer
        }
    ]
    });

    /* Set Up Pipeline */
    const pipelineLayout = device.createPipelineLayout({
        label: "Pipeline Layout",
        bindGroupLayouts: [ bindGroupLayout ],
    });

    const imageShaderModule = await utils.loadShaderModuleFromFile(device, "drawShader", "Draw Shader"); 

    const vertices = new Float32Array([
        -1.0, -1.0, // Triangle 1 (Blue)
        1.0, -1.0,
        1.0,  1.0,
        
        -1.0, -1.0, // Triangle 2 (Red)
        1.0,  1.0,
        -1.0,  1.0,
    ]);

    const vertexBuffer = device.createBuffer({
        lable: "Vertices",
        size: vertices.byteLength,
        usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST, 
    });

    device.queue.writeBuffer( vertexBuffer, 0, vertices );

    const vertexBufferLayout = {
        arrayStride: 2 * 4, // 2 floats per vertex, 4 bytes per float
        attributes: [{
            format: "float32x2",
            offset: 0,
            shaderLocation: 0,
        }]
    };

    const imagePipeline = device.createRenderPipeline({
        label: "Image Pipeline",
        layout: pipelineLayout,
        vertex: {
            module: imageShaderModule,
            entryPoint: "vertexMain",
            buffers: [vertexBufferLayout]
        },
        fragment: {
            module: imageShaderModule,
            entryPoint: "fragmentMain",
            targets: [{
                format: canvasFormat
            }]
        }
    });

    const caluclationShaderModule = await utils.loadShaderModuleFromFile(device, "calculationShader", "Calculation Shader"); 

    const caluclationPipeline = device.createComputePipeline({
        label: "Calculation Pipeline",
        layout: pipelineLayout,
        compute: {
            module: caluclationShaderModule,
            entryPoint: "computeMain",
        }
    });

     /* Create uniform buffer */
     const uniformArray = new Float32Array([IMAGE_SIZE, IMAGE_SIZE]);
     const uniformBuffer = device.createBuffer({
         label: "Grid Uniforms",
         size: uniformArray.byteLength,
         usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
     });
 
     device.queue.writeBuffer( uniformBuffer, 0, uniformArray );
 
     /* Pixel Data */
     const pixelStateData = new Float32Array(IMAGE_SIZE * IMAGE_SIZE);
     const pixelStateStorage = device.createBuffer({
        label: "Pixel State A",
        size: pixelStateData.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
     });
         
 
     for (let i = 0; i < pixelStateData.length; ++i) {
        pixelStateData[i] = 0;
     }
 
    device.queue.writeBuffer( pixelStateStorage,  0, pixelStateData);

    // uniform time buffer 
    const timeArray = new Float32Array([0.0]);
    const timeBuffer = device.createBuffer({
        label: "Time",
        size: timeArray.byteLength,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    device.queue.writeBuffer( timeBuffer, 0, timeArray);

    let mapData = new Float32Array(IMAGE_SIZE * IMAGE_SIZE);
    const mapBuffer = device.createBuffer({
        label: "Map",
        size: mapData.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });



    const map2 = perlin.generatePerlinNoise(IMAGE_SIZE, IMAGE_SIZE, 10, 10, 0.04);
    const map3 = perlin.generatePerlinNoise(IMAGE_SIZE, IMAGE_SIZE, 10, 10, 0.004);
    const map4 = perlin.generatePerlinNoise(IMAGE_SIZE, IMAGE_SIZE, 10, 10, 0.0004);
    
    for (let i = 0; i < map2.length; ++i) {
        mapData[i] = (map2[i] + map3[i] + map4[i]);
    }
    
    mapData = utils.NormalizeArray(mapData);

    device.queue.writeBuffer( mapBuffer, 0, mapData);

    let oceanData = new Float32Array([0.0005]);
    const oceanBuffer = device.createBuffer({
        label: "Ocean",
        size: oceanData.byteLength,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    device.queue.writeBuffer( oceanBuffer, 0, oceanData);

    let lightData = new Float32Array([0.0, 0.0, 0.0]);
    const lightBuffer = device.createBuffer({
        label: "Light",
        size: lightData.byteLength,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

   
      /* Create Bindgroups */
    const bindGroup = device.createBindGroup({
        lable: "Bind group",
        layout: bindGroupLayout,
        entries: [{
            binding: 0,
            resource: {buffer: uniformBuffer},
        }, {
            binding: 1,
            resource: {buffer: pixelStateStorage},
        }, {
            binding: 2,
            resource: {buffer: timeBuffer},
        }, {
            binding: 3,
            resource: {buffer: mapBuffer},
        },{
            binding: 4,
            resource: {buffer: oceanBuffer},
        }, {
            binding: 5,
            resource: {buffer: lightBuffer},
        }
    ]
    });

    
    var iteration = 0;
    function updateImage()
    {
        
        timeArray[0] += 0.1;
        device.queue.writeBuffer( timeBuffer, 0, timeArray);

        // let mouse = GetMousePosition();
        let rad = 250;
        lightData[0] = 512 + rad * Math.cos(iteration * 0.01);
        lightData[1] = 512 + rad * Math.sin(iteration * 0.01);
        lightData[2] = 6;
        
        device.queue.writeBuffer( lightBuffer, 0, lightData);

        // Create the command encoder
        const encoder = device.createCommandEncoder();
       
        const computePass = encoder.beginComputePass();

        computePass.setPipeline(caluclationPipeline);
        computePass.setBindGroup(0, bindGroup);

        const workgroupCount = Math.ceil(IMAGE_SIZE / WORKGROUP_SIZE);
        computePass.dispatchWorkgroups(workgroupCount, workgroupCount);

        computePass.end();

        const pass = encoder.beginRenderPass({
            colorAttachments: [{
                view: context.getCurrentTexture().createView(),
                clearValue: { r: 0.72, g: 0.7, b: 0.75, a: 1 }, // Clear to black
                loadOp: 'clear',
                storeOp: 'store',
            }],
        });

        // Begin the render pass
        pass.setPipeline(imagePipeline);
        pass.setVertexBuffer(0, vertexBuffer);
        pass.setBindGroup(0, bindGroup);
        pass.draw(vertices.length / 2); // Draw 3 vertices (1 triangle)
        pass.end();

        // Submit the commands
        device.queue.submit([encoder.finish()]);
        iteration++;
        window.requestAnimationFrame(updateImage);
    }
    window.requestAnimationFrame(updateImage);
    
}

function GetMousePosition(event) {
    var rect = canvas.getBoundingClientRect();
    return [event.clientX - rect.left, event.clientY - rect.top];
}

// Initialize WebGPU
initWebGPU();
