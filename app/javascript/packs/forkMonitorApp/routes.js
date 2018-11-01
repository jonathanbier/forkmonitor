import React from 'react'
import {
  BrowserRouter as Router,
  Route,
} from 'react-router-dom'
import LandingPage from './components/landingPage';
const App = (props) => (
    <div>
      <Router>
        <Route exact path='/' component={LandingPage} />
      </Router>
      <footer className="footer">
       <div className="container">
         <span className="text-muted">
         <p>Sponsored by:<br />
           <img src="https://blog.bitmex.com/wp-content/uploads/2018/11/logo.png" height="100pt"/>
         </p>
         <p className="text-muted disclaimer">
            This material should not be the basis for making investment decisions,
            nor be construed as a recommendation to engage in investment transactions,
            and is not related to the provision of advisory services regarding investment,
            tax, legal, financial, accounting, consulting or any other related services,
            nor is a recommendation being provided to buy, sell or purchase any good or product.
          </p>
          <p className="text-muted disclaimer">
            The information and data herein have been obtained from sources we believe to be reliable.
            Such information has not been verified and we make no representation or
            warranty as to its accuracy, completeness or correctness.
            The website is sponsored by BitMEX Research and neither BitMEX, nor
            any other entity, will be liable whatsoever for any direct or consequential
            loss arising from the use of this publication/communication or its contents.
          </p>
        </span>
       </div>
     </footer>
    </div>
)
export default App;
