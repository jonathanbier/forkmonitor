import React from 'react';

import axios from 'axios';

import {
    Breadcrumb,
    BreadcrumbItem,
    Col,
    Container,
    Row,
    Table,
    TabPane
} from 'reactstrap';

import Penalty from './penalty'

axios.defaults.headers.post['Content-Type'] = 'application/json'

class Lightning extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      penalties: [],
    };

    this.getPenalties = this.getPenalties.bind(this);
  }

  componentDidMount() {
    this.getPenalties();
  }

  getPenalties() {
    axios.get('/api/v1/ln_penalties.json').then(function (response) {
      return response.data;
    }).then(function (penalties) {
      this.setState({
        penalties: penalties
      });
      }.bind(this)).catch(function (error) {
        console.error(error);
      });
   }

  render() {
      return(
        <TabPane align="left" >
          <br />
          <Container>
            <Row><Col>
              <Breadcrumb  className="chaintip-header">
                <BreadcrumbItem className="chaintip-hash">
                  Lightning penalty transactions
                </BreadcrumbItem>
              </Breadcrumb>
              <p>
                See <a href="https://blog.bitmex.com/lightning-network-justice/" target="_blank">Lightning Network (Part 3) – Where Is The Justice?</a> for background.
              </p>
              <Table striped responsive size="sm" className="lightning">
                <thead>
                  <tr align="left">
                    <th>Date</th>
                    <th>Block</th>
                    <th>BTC</th>
                    <th>Transaction</th>
                  </tr>
                </thead>
                <tbody>
                  {(this.state && this.state.penalties || []).map(function (penalty, index) {
                    return (
                      <Penalty penalty={ penalty } key={penalty.id}/>
                    )
                  }.bind(this))}
                </tbody>
              </Table>
          </Col></Row>
        </Container>
      </TabPane>
    );
  }
}
export default Lightning
