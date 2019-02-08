import React from 'react';

import {
    Collapse,
    Navbar,
    NavbarBrand,
    Nav,
    NavItem,
    NavLink,
    Container,
    Row,
    Col,
    Jumbotron,
    TabContent,
} from 'reactstrap';

import {
  BrowserRouter as Router,
  Route,
  Redirect,
  Switch
} from 'react-router-dom'

import {
  LinkContainer
} from 'react-router-bootstrap'

import classnames from 'classnames';

import Nodes from './nodes';
import AdminPage from './adminPage';

class Navigation extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return(
      <div>
        <Router>
          <div>
            <Navbar color="inverse" light expand="md">
                <NavbarBrand href="/">Fork Monitor</NavbarBrand>
            </Navbar>
            <Nav tabs>
              <NavItem className="NavItem">
                <LinkContainer to="/nodes/btc">
                  <NavLink>Bitcoin</NavLink>
                </LinkContainer>
              </NavItem>
              <NavItem className="NavItem">
                <LinkContainer to="/nodes/bch">
                  <NavLink>Bitcoin Cash</NavLink>
                </LinkContainer>
              </NavItem>
              {
                window.location.pathname == "/admin" &&
                <NavItem className="NavItem">
                  <LinkContainer to="/admin">
                    <NavLink>Admin</NavLink>
                  </LinkContainer>
                </NavItem>
              }
            </Nav>
            <TabContent>
              <Switch>
                <Redirect exact path="/" to="/nodes/btc" />
                <Route path='/nodes/:coin' component={Nodes} />
                <Route path='/admin' component={AdminPage} />
              </Switch>
            </TabContent>
          </div>
        </Router>
      </div>
    );
  }
}
export default Navigation