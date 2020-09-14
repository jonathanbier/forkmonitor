import React from 'react';
import PropTypes from 'prop-types';

import axios from 'axios';

import { Redirect } from 'react-router'

import {
    Breadcrumb,
    BreadcrumbItem,
    Col,
    Container,
    Row,
    Table,
    TabPane
} from 'reactstrap';

import StaleCandidate from "./staleCandidate"
import Explorer from "./explorer"

axios.defaults.headers.post['Content-Type'] = 'application/json'

class StaleCandidates extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      redirect: false,
      staleCandidates: [],
      doubleSpends: [],
      coin: this.props.match.params.coin,
      height: this.props.match.params.height
    };

    this.getStaleCandidates = this.getStaleCandidates.bind(this);
  }

  componentDidMount() {
    this.getStaleCandidates();
  }

  getStaleCandidates() {
    axios.get(`/api/v1/stale_candidates/${ this.state.coin }/${ this.state.height }.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
        coin: res.coin,
        staleCandidates: res.children,
        doubleSpends: res.double_spend_candidates
      });
      }.bind(this)).catch(function (error) {
        if (error.response.status == 404) {
          this.setState({ redirect: true })
        } else {
          console.error(error);
        }
      }.bind(this));
   }

  render() {
    const { redirect } = this.state;
    const coin = this.state.coin;

    if (redirect) {
      return <Redirect to={ `/nodes/${ coin }` } />;
    }

    return(
      <TabPane align="left" >
        <br />
        <Container>
          <Row><Col>
            <Breadcrumb  className="chaintip-header">
              <BreadcrumbItem className="chaintip-hash">
                Stale block candidates at height { this.state.height }
              </BreadcrumbItem>
            </Breadcrumb>
            <p>
              Multiple blocks were produced at height { this.state.height }.
              As new blocks are mined that reference one of these blocks as their
              parent, the heaviest chain survives and the other blocks become
              stale.
              Some explorers will forget the stale block(s).
              The timestamp as reported in a block is not necessarily accurate,
              as explained in <a href="https://blog.bitmex.com/bitcoins-block-timestamp-protection-rules/" target="_blank">Bitcoin’s Block Timestamp Protection Rules</a>.
            </p>
            <Table striped responsive size="sm" className="lightning">
              <thead>
                <tr align="left">
                  <th>Length</th>
                  <th>Hash</th>
                  <th>Timestamp</th>
                  <th>Pool</th>
                  <th>Root</th>
                  <th>Tip</th>
                </tr>
              </thead>
              <tbody>
                {this.state.staleCandidates.map(function (child, index) {
                  return (
                    <StaleCandidate coin={ coin } root={ child.root } tip={ child.tip } length={ child.length } key={index}/>
                  )
                })}
              </tbody>
            </Table>
            { (this.state.doubleSpends == null ||  this.state.doubleSpends.length == 0) &&
              <p>No double spends have been detected</p>
            }
            { this.state.doubleSpends != null && this.state.doubleSpends.length > 0 &&
              <div>
                <p>
                  { this.state.doubleSpends.length } potential doublespends have
                  been detected. Some transaction may still appear in future blocks.
                  The following list may contain false positives due to an RBF fee bump,
                  or because it was included after our 10 block scan window.
                </p>
                <Table striped responsive size="sm" className="lightning">
                  <thead>
                    <tr align="left">
                      <th>Hash</th>
                      <th>Explorer</th>
                    </tr>
                  </thead>
                  <tbody>
                    {this.state.doubleSpends.map(function (tx_id, index) {
                      return (
                        <tr key={ index }>
                          <td>
                            { tx_id }
                          </td>
                          <td>
                            <Explorer blockstream coin={ coin } tx={ tx_id }/>&nbsp;
                            <Explorer btcCom coin={ coin } tx={ tx_id }/>
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </Table>
              </div>
            }
          </Col></Row>
        </Container>
      </TabPane>
    );
  }
}

StaleCandidates.propTypes = {
}

export default StaleCandidates
