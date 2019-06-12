import 'bootstrap/dist/css/bootstrap'

import React from 'react'

import Navigation from './components/navigation';

const App = (props) => (
    <div>
      <Navigation />
      <footer className="footer">
       <div className="container">
         <span className="text-muted">
         <p>
           <a href="https://research.bitmex.com"><img src="https://blog.bitmex.com/wp-content/uploads/2019/05/BitMEX-Research-Logo-Color-RGB.png" height="100pt"/></a>
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
          <p className="text-muted disclaimer">
            Source code on <a href="https://github.com/BitMEXResearch/forkmonitor">Github</a>
          </p>
        </span>
       </div>
     </footer>
    </div>
)
export default App;
