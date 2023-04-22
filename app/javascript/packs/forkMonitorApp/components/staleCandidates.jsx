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

import ConflictingTransaction from "./conflictingTransaction"
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
      loading: true,
      redirect: false,
      staleCandidates: [],
      missingTransactions: null,
      confirmedInOneBranch: null,
      confirmedInOneBranchTotal: null,
      doubleSpent: null,
      doubleSpentBy: null,
      doubleSpentTotal: null,
      rfb: null,
      rbfBy: null,
      height: this.props.match.params.height
    };

    this.getStaleCandidates = this.getStaleCandidates.bind(this);
    this.getDoubleSpendInfo = this.getDoubleSpendInfo.bind(this);
  }

  componentDidMount() {
    // Sequence shouldn't matter
    this.getMaxHeight();
    this.getStaleCandidates();
    this.getDoubleSpendInfo();
  }

  getDoubleSpendInfo() {
    axios.get(`/api/v1/stale_candidates/${ this.state.height }/double_spend_info.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
        loading: false,
        missingTransactions: res.missing_transactions,
        confirmedInOneBranch: res.confirmed_in_one_branch,
        confirmedInOneBranchTotal: res.confirmed_in_one_branch_total,
        doubleSpent: res.double_spent_in_one_branch,
        doubleSpentTotal: res.double_spent_in_one_branch_total,
        doubleSpentBy: res.double_spent_by,
        rbf: res.rbf,
        rbfBy: res.rbf_by,
        rbfTotal: res.rbf_total,
        heightProcessed: res.height_processed
      });
      }.bind(this)).catch(console.error);
   }

  getStaleCandidates() {
    axios.get(`/api/v1/stale_candidates/${ this.state.height }.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
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

  getMaxHeight() {
    axios.get(`/api/v1/blocks/max_height.json`).then(function (response) {
      return response.data;
    }).then(function (res) {
      this.setState({
        maxHeight: res
      });
      }.bind(this)).catch(console.error);
  }

  render() {
    const { redirect } = this.state;
    const doubleSpentBy = this.state.doubleSpentBy;
    const rbfBy = this.state.rbfBy;

    if (redirect) {
      return <Redirect to={ `/nodes/btc` } />;
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
            { this.state.heightProcessed != null &&
              <p>
                The data on this page includes blocks up to { this.state.heightProcessed }.&nbsp;
                { this.state.heightProcessed - this.state.height > 100 &&
                  <span>
                    We do not check for conflicting transactions beyond 100 blocks.
                  </span>
                }
                { this.state.maxHeight - this.state.heightProcessed > 0 && this.state.heightProcessed - this.state.height <= 100 &&
                  <span>
                    Processing newly detected block(s) up to { this.state.maxHeight }...&nbsp;
                    <FontAwesomeIcon
                      className="fa-pulse"
                      icon={ faSpinner }
                    />
                  </span>
                }
              </p>
            }
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
                    <StaleCandidate root={ child.root } tip={ child.tip } length={ child.length } key={index} />
                  )
                })}
              </tbody>
            </Table>
            <div>
              <h3>Conflicting Transactions</h3>
              <p>
                If a transaction occurs in one branch <i>and a conflicting
                transaction occurs in the other branch</i>, then it could be an RBF
                fee increase or a double-spend attempt.
              </p>
              { this.state.loading &&
                <FontAwesomeIcon
                  className="fa-pulse"
                  icon={ faSpinner }
                />
              }
              { !this.state.loading &&
                <span>
                  { (this.state.headersOnly || this.state.missingTransactions ) &&
                    <p>Due to missing block data we are currently unable to check this.</p>
                  }
                  { !this.state.missingTransactions && this.state.doubleSpent.length == 0 &&
                    <p>No double spends have been detected</p>
                  }
                  { !this.state.missingTransactions && this.state.doubleSpent.length > 0 &&
                    <div>
                        <p>{ this.state.doubleSpent.length } transaction(s)
                        involving { this.state.doubleSpentTotal } BTC have been doublespent
                        on the longest chain.
                      </p>
                      <Table striped responsive className="conflicting-transactions">
                        <thead>
                          <tr align="left">
                            <th style={ {width: "100pt"} }>BTC</th>
                            <th>In shortest branch</th>
                            <th>In longest branch</th>
                          </tr>
                        </thead>
                        <tbody>
                          {this.state.doubleSpent.map(function (tx, index) {
                            return (
                              <ConflictingTransaction key={index} tx={ tx } conflict={ doubleSpentBy[index] }/>
                            )
                          })}
                        </tbody>
                      </Table>
                    </div>
                  }
                  { !this.state.missingTransactions && this.state.rbf.length == 0 &&
                    <p>No (RBF) fee bumps have been detected</p>
                  }
                  { !this.state.missingTransactions && this.state.rbf.length > 0 &&
                    <div>
                        <p>{ this.state.rbf.length } transaction(s)
                        involving { this.state.rbfTotal } BTC have been fee bumped
                        on the longest chain. Presence of an RBF flag is not considered here.
                        For each output, we check if was changed by less than 0.0001 BTC.
                      </p>
                      <Table striped responsive size="sm" className="lightning">
                        <thead>
                          <tr align="left">
                            <th style={ {width: "100pt"} }>BTC</th>
                            <th>In shortest branch</th>
                            <th>In longest branch</th>
                          </tr>
                        </thead>
                        <tbody>
                          {this.state.rbf.map(function (tx, index) {
                            return (<ConflictingTransaction
                                key={index}
                                tx={ tx }
                                conflict={ rbfBy[index] }
                              />)
                          })}
                        </tbody>
                      </Table>
                    </div>
                  }
                </span>
              }
              { this.state.missingTransactions == false && this.state.confirmedInOneBranch.length > 0 &&
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
                              <Explorer blockstream tx={ tx.tx_id }/>&nbsp;
                              <Explorer btcCom tx={ tx.tx_id }/>
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
