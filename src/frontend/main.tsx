import                        './styles.scss';
import App            from './components/App';

import { HashRouter } from "react-router-dom";
import ReactDOM       from 'react-dom/client';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <HashRouter>
    <App />
  </HashRouter>
);
