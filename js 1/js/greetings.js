const loginInput = document.querySelector("#login-form input");
const loginForm = document.querySelector("#login-form");
const greeting = document.querySelector("#greeting");

const HIDDEN_CLASS = "hidden"
const USERNAME_KEY = "username"

function onLoginSubmit(event){
    event.preventDefault();
    loginForm.classList.add(HIDDEN_CLASS);
    const username = loginInput.value;
    localStorage.setItem(USERNAME_KEY , username)
    paintGreetings(username);
    }

loginForm.addEventListener("submit", onLoginSubmit);

const savedUsername = localStorage.getItem(USERNAME_KEY)

function paintGreetings(name){
    greeting.innerText = `Hello ${name}`;
    greeting.classList.remove(HIDDEN_CLASS);
}

if (savedUsername === null){
    //값이 없다는 거니 로그인 창을 보여줘
    loginForm.classList.remove(HIDDEN_CLASS)
}
else{
    //값이 있는 것이니 greeting만 보여주면 돼
    paintGreetings(savedUsername)
}
