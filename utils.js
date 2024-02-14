async function loadFileText(url) {
    return (await fetch(url)).text().then((text) => {return text});
  }

async function loadShaderModuleFromFile(device, url, lable) {
  const code = await loadFileText("shaders/"+url+".wgsl");
  return device.createShaderModule({ 
    lable: lable,
    code: code 
  });
}
function lerp1D(a, b, t ) {
  return a + t * (b - a);
}
function lerp2D(a, b, t) {
  return [lerp1D(a[0], b[0],t), lerp1D(a[1], b[1], t)];
}

function distance(a, b) {
  return Math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2);
}
function clamp(x, min, max) {
  return Math.min(Math.max(x, min), max);
}

export {loadShaderModuleFromFile, lerp1D, lerp2D, distance, clamp };