const images = ["1.jpg" , "2.jpg" , "3.jpg"];

const chosenImage = images[Math.floor(Math.random()* images.length)]; // 1.jpg 같은 사진파일 이름

const bgImage = document.createElement("img")

bgImage.src = `img/${chosenImage}`;

console.log(bgImage)

document.body.appendChild(bgImage)