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

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faRss } from '@fortawesome/free-solid-svg-icons'

import {
  BrowserRouter as Router,
  Route,
  Redirect,
  Switch
} from 'react-router-dom'

import {
  LinkContainer
} from 'react-router-bootstrap'

import withTracker from './withTracker';

import LogoImage from '../assets/images/logo.png'

import classnames from 'classnames';

import Nodes from './nodes';
import AdminPage from './adminPage';
import NotificationsPage from './notificationsPage';

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
                <NavbarBrand href="/"><img src={ LogoImage } height="39pt"/></NavbarBrand>
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
              <NavItem className="NavItem">
                <LinkContainer to="/nodes/bsv">
                  <NavLink>Bitcoin SV</NavLink>
                </LinkContainer>
              </NavItem>
              <NavItem className="NavItem">
                <LinkContainer to="/notifications">
                  <NavLink><FontAwesomeIcon icon={faRss} /></NavLink>
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
                <Route path='/nodes/:coin' component={withTracker(Nodes, { /* additional attributes */ } )} />
                <Route path='/admin' component={AdminPage} />
                <Route path='/notifications' component={NotificationsPage} />
              </Switch>
            </TabContent>
          </div>
        </Router>
      </div>
    );
  }
}
export default Navigation
