import Header from "./Header";
import Footer from "./Footer";
import GruntList from "./GruntList";

function App () {

  return (
    <div className="flex flex-col min-h-screen w-full bg-white dark:bg-slate-900 dark:border-gray-700 justify-between">
      <div className="flex flex-col w-full flex-grow items-center">
        <Header/>
        <GruntList/>
      </div>
      <Footer/>
    </div>
  )
}

export default App;