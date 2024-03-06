function resetUpload() {
  document.getElementById("imageUpload").value = '';
  document.getElementById('preview').style.display = 'none';
  document.getElementById('send-container').style.display = 'none';
  let response = document.getElementById('response');
  response.style.display = 'none';
  response.value = '';
}

function uploadImage(event) {
  if (event.target.files.length == 0) return;

  // copied from https://stackoverflow.com/a/59711776
  let reader = new FileReader();
  reader.readAsDataURL(event.target.files[0]);
  reader.onload = () => {
    const docs = {
      name: event.target.files[0].name,
      size: event.target.files[0].size,
      lastModifiedDate: event.target.files[0].lastModifiedDate,
      base64: reader.result
    }
    let preview = document.getElementById('preview');
    preview.src = docs.base64;
    preview.style.display = 'block';
    let button = document.getElementById('send-container');
    button.style.display = 'flex';
  }
}

function processLine(line) {
  const obj = JSON.parse(line);
  if (obj == null) return;
  if (obj.error != null) {
    resetUpload();
    alert(obj.error);
    return;
  }
  if (obj.response != null) {
    document.getElementById('response').value += obj.response;
    //console.log('chunk: ' + obj.response);
    return;
  }
}

// Function to read a stream line by line
async function readStreamLineByLine(stream) {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let partialLine = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value, { stream: true });
    const lines = (partialLine + chunk).split('\n');
    partialLine = lines.pop(); // Store incomplete line for the next iteration

    for (const line of lines) {
      // Process each line here
      processLine(line);
    }
  }

  // Process the remaining partial line, if any
  if (partialLine) {
    // Process the last line
    processLine(partialLine);
  }

  reader.releaseLock();
}

function sendRequest() {
  document.getElementById('response').value = '';
  let imageSrc = document.getElementById('preview').src;
  if (imageSrc == null | imageSrc.length == 0) {
    resetUpload();
    alert('could not get image');
    return;
  }

  let index = imageSrc.indexOf(';base64,');
  if (index == -1) {
    resetUpload();
    alert('could not decode image');
    return;
  }
  index += ';base64,'.length;
  imageSrc = imageSrc.substring(index);
  let payload = {
    model: "llava",
    prompt: document.getElementById('prompt').value,
    images: [imageSrc]
  }
  const response = fetch(
    '/api/generate',
    {
      method: 'POST',
      referrer: '',
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    })
    .then(response => {
        let responseui = document.getElementById('response');
        responseui.value = '';
        responseui.style.display = 'block';
        return response.body;
    })
    .then(readStreamLineByLine)
    .catch(error => {
        alert('error fetching stream');
        console.log(error);
    });
}
