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
import { faBolt } from '@fortawesome/free-solid-svg-icons'

import {
  BrowserRouter as Router,
  Route,
  Redirect,
  Switch
} from 'react-router-dom'

import {
  LinkContainer
} from 'react-router-bootstrap'

import actionCable from 'actioncable';

import withTracker from './withTracker';

import LogoImage from '../assets/images/logo.png'

import classnames from 'classnames';

import Block from './block';
import Lightning from './lightning';
import Nodes from './nodes';
import StaleCandidates from './staleCandidates';
import AdminPage from './adminPage';
import NotificationsPage from './notificationsPage';

const CableApp = {};

CableApp.cable = actionCable.createConsumer(process.env.NODE_ENV == 'production' ? 'wss://forkmonitor.info/cable' : 'ws://localhost:3000/cable');

class Navigation extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return(
      <div>
        <Router cableApp={CableApp}>
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
                <LinkContainer to="/lightning">
                  <NavLink><FontAwesomeIcon icon={faBolt} color="orange" /></NavLink>
                </LinkContainer>
              </NavItem>
              <NavItem className="NavItem">
                <LinkContainer to="/nodes/tbtc">
                  <NavLink>Testnet</NavLink>
                </LinkContainer>
              </NavItem>
              <NavItem className="NavItem">
                <LinkContainer to="/nodes/bsv">
                  <NavLink>BSV</NavLink>
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
              {
                window.location.pathname.startsWith("/blocks") &&
                <NavItem className="NavItem">
                  <LinkContainer to={ window.location.pathname }>
                    <NavLink>Block</NavLink>
                  </LinkContainer>
                </NavItem>
              }
            </Nav>
            <TabContent>
              <Switch>
                <Redirect exact path="/" to="/nodes/btc" />
                <Route path='/blocks/:coin/:hash' component={withTracker(Block, { /* additional attributes */ })} />
                <Route path='/nodes/:coin' component={withTracker(Nodes, { /* additional attributes */ }, {cableApp: CableApp} )} />
                <Route path='/lightning' component={withTracker(Lightning, { /* additional attributes */ } )} />
                <Route path='/admin' component={AdminPage} />
                <Route path='/notifications' component={withTracker(NotificationsPage, { /* additional attributes */ } )} />
                <Route path='/stale/:coin/:height' component={withTracker(StaleCandidates, { /* additional attributes */ } )} />
              </Switch>
            </TabContent>
          </div>
        </Router>
      </div>
    );
  }
}
export default Navigation
