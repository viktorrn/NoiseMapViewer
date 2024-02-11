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

function Gaussian2D(pos, sigma, mean, amplitude, scew) {
    let x = pos[0]-mean[0];
    let y = pos[1]-mean[1];
    let d = (scew[0]*x*x + scew[1]*y*y) / (2*sigma*sigma);
    return amplitude*Math.exp(-d);
}

function NormalizeArray(array) {
  console.log(array);
  let max = -Math.infinity;
  for(let i = 0; i < array.length; i++) {
    if(array[i] > max) {
      max = array[i];
    }
  }
  console.log(max);
  let min = Math.infinity;
  for(let i = 0; i < array.length; i++) {
    if(array[i] < min) {
      min = array[i];
    }
  }
  console.log(min);
  let range = max - min;
  return array.map((x) => (x-min)/range);
}

export {loadShaderModuleFromFile, Gaussian2D, NormalizeArray };