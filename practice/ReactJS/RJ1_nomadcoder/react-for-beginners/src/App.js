import { useState } from "react";

function App() {
  const [counter, setCounter] = useState(0);
  const onClick = () => setCounter(counter + 1);
  return (
    <div>
      <h1>{counter}</h1>
      <button onClick={onClick}>Click me!</button>
    </div>
  );
}

export default App;
