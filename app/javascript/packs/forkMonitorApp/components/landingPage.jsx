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
    UncontrolledAlert
} from 'reactstrap';

import Nodes from './nodes';

class LandingPage extends React.Component {
  constructor(props) {
    super(props);

    this.toggle = this.toggle.bind(this);
    this.state = {
        isOpen: false
    };
  }
  toggle() {
      this.setState({
          isOpen: !this.state.isOpen
      });
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
                            <NavLink href="https://blog.bitmex.com/research/">BitMEX Research</NavLink>
                        </NavItem>
                    </Nav>
                </Collapse>
            </Navbar>
            <Jumbotron>
                <Container>
                    <Row>
                        <Col>
                            <h1>Bitcoin Cash Nodes</h1>
                        </Col>
                    </Row>
                </Container>
            </Jumbotron>
            <UncontrolledAlert color="info">
              Bitcoin Cash is expected to conduct a hardfork upgrade at about 16:40UTC on 15th November 2018
            </UncontrolledAlert>
            <Nodes/>
        </div>
      );
  }
}
export default LandingPage
