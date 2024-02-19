// Get the canvas element and its context
import * as utils from "./utils.js";
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
            buffer: { type: "read-only-storage" } // Time buffer
        }, {
            binding: 3,
            visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
            buffer: { type: "read-only-storage" } // Map buffer
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
    // [0]: Time, [1]: TimeScale, [2]: Change Gradient, [3]: Light position x [4]: Light position y [5]: Light position z  [6]: Ocean level [7]: Normal varaiance [8]: terrain tine
    const settingsArray = new Float32Array([0.0, 1.0, 0.0, 512, 512, 0.3, 0.005, 230, 0]);
    const settingsBuffer = device.createBuffer({
        label: "Settings",
        size: settingsArray.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });

    device.queue.writeBuffer( settingsBuffer, 0, settingsArray);

    let mapData = new Float32Array(IMAGE_SIZE * IMAGE_SIZE);
    const mapBuffer = device.createBuffer({
        label: "Map",
        size: mapData.byteLength,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });



    device.queue.writeBuffer( mapBuffer, 0, mapData);

    
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
            resource: {buffer: settingsBuffer},
        }, {
            binding: 3,
            resource: {buffer: mapBuffer},
        }
    ]
    });

    function updateNoiseMap()
    {
        const encoder = device.createCommandEncoder();  
        const computePass = encoder.beginComputePass();
    
        computePass.setPipeline(caluclationPipeline);
        computePass.setBindGroup(0, bindGroup);
    
        const workgroupCount = Math.ceil(IMAGE_SIZE / WORKGROUP_SIZE);
        computePass.dispatchWorkgroups(workgroupCount, workgroupCount);
    
        computePass.end();
        device.queue.submit([encoder.finish()]);
    }

    updateNoiseMap();
    var iteration = 0;
    var timeStamp = new Date().getTime();
    function updateImage()
    {
        if(document.getElementById('change-terrain').checked == 1)
        {
            settingsArray[2] = 1;
            settingsArray[8] += 0.1;
            updateNoiseMap();
        }
        else {
            settingsArray[2] = 0;
        }

        //caluclate delta time 
        let currentTime = new Date().getTime();
        
        if(settingsArray[7] != Number(document.getElementById('terrain-spread').value))
        {
            settingsArray[2] = 1;
            settingsArray[7] = Number(document.getElementById('terrain-spread').value);

            device.queue.writeBuffer( settingsBuffer, 0, settingsArray);
            updateNoiseMap();
        }
      
        const encoder = device.createCommandEncoder();

        settingsArray[0] += 0.1;
        
        settingsArray[1] = Number(document.getElementById('time-scale').value);

        // let mouse = GetMousePosition();
        // [0]: Time, [1]: TimeScale, [2]: Change Gradient, [3]: Light position x [4]: Light position y [5]: Light position z  [6]: Ocean level [7]: Normal varaiance [8]: terrain tine
        let rad = 450;
        
        let dx = 512 + rad * Math.cos(iteration * 0.001);
        let dy = 512 + rad * Math.sin(iteration * 0.001);

        if(mouseInside && document.getElementById('light-follow-mouse').checked == 1)
        {
            dx = mousePosition[0];
            dy = mousePosition[1];
            settingsArray[3] = dx;
            settingsArray[4] = dy;
        } else {
            let dist = utils.distance([settingsArray[3],settingsArray[4]],[dx,dy]);
        
            settingsArray[3] = utils.lerp1D(settingsArray[3],dx,utils.clamp(10/dist,0,1));
            settingsArray[4] = utils.lerp1D(settingsArray[4],dy,utils.clamp(10/dist,0,1));
        }

   
       
        settingsArray[5] = Number(document.getElementById('light-height').value);
        

    

        //oceanData[0] = Number(document.getElementById('ocean-level').value);
        device.queue.writeBuffer( settingsBuffer, 0, settingsArray);
        // Create the command encoder
        

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
        let deltaTime = currentTime - timeStamp;
        timeStamp = currentTime;
        
        document.getElementById('fps').innerHTML = "fps: " + Math.floor(1000/deltaTime);
    }
    window.requestAnimationFrame(updateImage);
    
}

function GetMousePosition(event) {
    var rect = canvas.getBoundingClientRect();
    return [event.clientX - rect.left,  rect.height + rect.top - event.clientY  ];
}

let mouseInside = false;
let mousePosition = [0,0];

canvas.onmousemove = (e)=>{
    try {
        mousePosition = GetMousePosition(e);
    } catch (error) {
        
    }
}

canvas.onmouseenter = ()=>{
    mouseInside = true;  
}

canvas.onmouseleave = ()=>{
    mouseInside = false; 
}
// Initialize WebGPU
initWebGPU();
