import React from 'react';
import PropTypes from 'prop-types';

import axios from 'axios';
import axiosRetry from 'axios-retry';

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

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faSpinner } from '@fortawesome/free-solid-svg-icons'

import StaleCandidate from "./staleCandidate"
import Explorer from "./explorer"

axios.defaults.headers.post['Content-Type'] = 'application/json'

axiosRetry(axios, {
  retries: 1000,
  retryDelay: (retryCount, error) => {
    var delay =  error.response.headers['retry-after'];
    return delay * 1000;
  },
  retryCondition: (error) => {
    return error.response.status == 503;
  }
});

class StaleCandidates extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      redirect: false,
      staleCandidates: [],
      confirmedInOneBranch: null,
      confirmedInOneBranchTotal: null,
      doubleSpent: null,
      doubleSpentTotal: null,
      coin: this.props.match.params.coin,
      height: this.props.match.params.height
    };

    this.getStaleCandidates = this.getStaleCandidates.bind(this);
    this.getDoubleSpendInfo = this.getDoubleSpendInfo.bind(this);
  }

  componentDidMount() {
    // Sequence shouldn't matter
    this.getStaleCandidates();
    this.getDoubleSpendInfo();
  }

  getDoubleSpendInfo() {
    axios.get(`/api/v1/stale_candidates/${ this.state.coin }/${ this.state.height }/double_spend_info.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
        confirmedInOneBranch: res.confirmed_in_one_branch,
        confirmedInOneBranchTotal: res.confirmed_in_one_branch_total,
        doubleSpent: res.double_spent_in_one_branch,
        doubleSpentTotal: res.double_spent_in_one_branch_total,
        rbf: res.rbf,
        rbfTotal: res.rbf_total,

      });
      }.bind(this)).catch(console.error);
   }

  getStaleCandidates() {
    axios.get(`/api/v1/stale_candidates/${ this.state.coin }/${ this.state.height }.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
        coin: res.coin,
        staleCandidates: res.children,
        headersOnly: res.headers_only
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
              We also indicate when we first saw the block. There can
              be a slight delay between when our nodes first detect a block
              and when our system processes it.
            </p>
            <Table striped responsive size="sm" className="lightning">
              <thead>
                <tr align="left">
                  <th>Length</th>
                  <th>Hash</th>
                  <th>Timestamp</th>
                  <th>First seen</th>
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
            { this.state.confirmedInOneBranch == null &&
              <span>
                { this.state.headersOnly &&
                  <p>Due to missing block data we are currently unable to check for potential double spends.</p>
                }
                { !this.state.headersOnly &&
                  <FontAwesomeIcon
                    className="fa-pulse"
                    icon={ faSpinner }
                  />
                }
              </span>
            }
            <div>
              <h3>Conflicting Transactions</h3>
              <p>
                If a transaction occurs in one branch <i>and a conflicting
                transaction occurs in the other branch</i>, then it may be an RBF
                fee increase or a double-spend.
              </p>
              { this.state.doubleSpent != null && this.state.doubleSpent.length == 0 &&
                <p>No double spends have been detected</p>
              }
              { this.state.doubleSpent != null && this.state.doubleSpent.length > 0 &&
                <div>
                    <p>{ this.state.doubleSpent.length } transaction(s)
                    involving { this.state.doubleSpentTotal } BTC have been doublespent
                    on the longest chain.
                  </p>
                  <Table striped responsive size="sm" className="lightning">
                    <thead>
                      <tr align="left">
                        <th>Hash</th>
                        <th>BTC</th>
                        <th>Explorer</th>
                      </tr>
                    </thead>
                    <tbody>
                      {this.state.doubleSpent.map(function (tx, index) {
                        return (
                          <tr key={ index }>
                            <td>
                              { tx.tx_id }
                            </td>
                            <td>
                              { tx.amount }
                            </td>
                            <td>
                              <Explorer blockstream coin={ coin } tx={ tx.tx_id }/>&nbsp;
                              <Explorer btcCom coin={ coin } tx={ tx.tx_id }/>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </Table>
                </div>
              }
              { this.state.rbf != null && this.state.rbf.length == 0 &&
                <p>No (RBF) fee bumps have been detected</p>
              }
              { this.state.rbf != null && this.state.rbf.length > 0 &&
                <div>
                    <p>{ this.state.rbf.length } transaction(s)
                    involving { this.state.rbfTotal } BTC have been fee bumped
                    on the longest chain. Presence of an RBF flag is not considered here.
                    For each output, we check if was changed by less than 0.0001 BTC.
                  </p>
                  <Table striped responsive size="sm" className="lightning">
                    <thead>
                      <tr align="left">
                        <th>Hash</th>
                        <th>BTC</th>
                        <th>Explorer</th>
                      </tr>
                    </thead>
                    <tbody>
                      {this.state.rbf.map(function (tx, index) {
                        return (
                          <tr key={ index }>
                            <td>
                              { tx.tx_id }
                            </td>
                            <td>
                              { tx.amount }
                            </td>
                            <td>
                              <Explorer blockstream coin={ coin } tx={ tx.tx_id }/>&nbsp;
                              <Explorer btcCom coin={ coin } tx={ tx.tx_id }/>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </Table>
                </div>
              }
              { this.state.confirmedInOneBranch != null && this.state.confirmedInOneBranch.length > 0 &&
                <div>
                  <h3>Transactions not seen in both branches</h3>
                  <p>
                    { this.state.confirmedInOneBranch.length } transactions
                    involving { this.state.confirmedInOneBranchTotal } BTC
                    have been detected that occur on the shortest side of the split,
                    but not on the longest (except if they are the same length).
                    Usually this happens because different miners select a slightly
                    different set of transactions for their block. In that case they
                    should appear in future blocks.
                  </p>
                  <p>
                    It is unsafe to consider these transactions confirmed, because
                    an opportunistic sender could still broadcast a conflicting
                    replacement transaction which, if it ends up in the heaviest chain,
                    would doublespend the original. We may add detection for this later.
                  </p>
                  <p>
                    Another possiblity is that a transaction fee was increased using
                    RBF and that one miner didn't receive the fee increase in time.
                    We may add detection for this later.
                  </p>
                  <p>
                    The list below is updated every block until 30 blocks after the split.
                  </p>
                  <Table striped responsive size="sm" className="lightning">
                    <thead>
                      <tr align="left">
                        <th>Hash</th>
                        <th>BTC</th>
                        <th>Explorer</th>
                      </tr>
                    </thead>
                    <tbody>
                      {this.state.confirmedInOneBranch.map(function (tx, index) {
                        return (
                          <tr key={ index }>
                            <td>
                              { tx.tx_id }
                            </td>
                            <td>
                              { tx.amount }
                            </td>
                            <td>
                              <Explorer blockstream coin={ coin } tx={ tx.tx_id }/>&nbsp;
                              <Explorer btcCom coin={ coin } tx={ tx.tx_id }/>
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </Table>
                </div>
              }
            </div>
          </Col></Row>
        </Container>
      </TabPane>
    );
  }
}

StaleCandidates.propTypes = {
}

export default StaleCandidates
