import React from 'react';

import {
    Collapse,
    Navbar,
    NavbarToggler,
    NavbarBrand,
    Nav,
    NavItem,
    NavLink,
    Container,
    Row,
    Col,
    Jumbotron,
    UncontrolledAlert,
    TabContent,
    TabPane
} from 'reactstrap';

import classnames from 'classnames';

import Nodes from './nodes';

class LandingPage extends React.Component {
  constructor(props) {
    super(props);

    this.toggle = this.toggle.bind(this);
    this.toggleTab = this.toggleTab.bind(this);

    this.state = {
        isOpen: false,
        activeTab: '1'
    };
  }
  toggle() {
      this.setState({
          isOpen: !this.state.isOpen
      });
  }
  toggleTab(tab) {
    if (this.state.activeTab !== tab) {
      this.setState({
        activeTab: tab
      });
    }
   }

  render() {
      return(
        <div>
            <Navbar color="inverse" light expand="md">
                <NavbarBrand href="/">Fork Monitor</NavbarBrand>
                <NavbarToggler onClick={this.toggle} />
                <Collapse isOpen={this.state.isOpen} navbar>
                    <Nav className="ml-auto" navbar>
                        <NavItem>
                            <NavLink href="https://github.com/BitMEXResearch/forkmonitor">Github</NavLink>
                        </NavItem>
                    </Nav>
                </Collapse>
            </Navbar>
            <Nav tabs>
              <NavItem>
                <NavLink
                  className={classnames({ active: this.state.activeTab === '1' })}
                  onClick={() => { this.toggleTab('1'); }}
                >
                  Bitcoin
                </NavLink>
              </NavItem>
              <NavItem>
                <NavLink
                  className={classnames({ active: this.state.activeTab === '2' })}
                  onClick={() => { this.toggleTab('2'); }}
                >
                  Bitcoin Cash
                </NavLink>
              </NavItem>
            </Nav>
            <TabContent activeTab={this.state.activeTab}>
             <TabPane tabId="1" align="lef">
              <br />
               <Nodes coin="BTC"/>
             </TabPane>
             <TabPane tabId="2">
               <UncontrolledAlert color="info">
                 Bitcoin Cash is expected to conduct a hardfork upgrade at about 16:40UTC on 15th November 2018
               </UncontrolledAlert>
               <Nodes coin="BCH"/>
             </TabPane>
           </TabContent>
        </div>
      );
  }
}
export default LandingPage
