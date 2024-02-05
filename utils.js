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

export {loadShaderModuleFromFile };