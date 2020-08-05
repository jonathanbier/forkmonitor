import React from 'react';

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

axios.defaults.headers.post['Content-Type'] = 'application/json'

class StaleCandidates extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      redirect: false,
      staleCandidates: [],
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
        staleCandidates: res.children
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

    if (redirect) {
      return <Redirect to={ `/nodes/${ this.state.coin }` } />;
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
                    <StaleCandidate root={ child.root } tip={ child.tip } length={ child.length } key={index}/>
                  )
                })}
              </tbody>
            </Table>
          </Col></Row>
        </Container>
      </TabPane>
    );
  }
}
export default StaleCandidates
