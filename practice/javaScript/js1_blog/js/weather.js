const API_KEY = "96a80d8f49b4eb1538c2f6ca04f36d3c"
function onGeoOk(position){
    const lat = position.coords.latitude;
    const lon = position.coords.longitude;
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${API_KEY}&units=metric`
    fetch(url).then(response => response.json()).then(data => { 
        const weather= document.querySelector("#weather span:first-child");
        const city = document.querySelector("#weather span:last-child")

        weather.innerText = `${data.weather[0].main} / ${data.main.temp} degree`;
        city.innerText = data.name;
    });
}

function onGeoError(){
    alert("can't find you")
}

navigator.geolocation.getCurrentPosition(onGeoOk, onGeoError); //wifi gps 날씨