import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Nodes from 'forkMonitorApp/components/nodes';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

test('rendered component', async () => {
  const best_block = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }
  const resp = {data: [
    {id: 1, name: "Bitcoin Core", version: 170100, best_block: best_block, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, best_block: best_block, unreachable_since: null, ibd: false}
  ]}
  axios.get.mockResolvedValue(resp);

  const wrapper = shallow(<Nodes match={{params: {coin: 'BTC'}}} />);
  await flushPromises();
  expect(wrapper.find('Chaintip')).toHaveLength(1);
  expect(wrapper.find('NodesWithoutTip')).toHaveLength(0);
});

test('can handle node without best block', async () => {
  const best_block = {
    hash: "abcd",
    height: 500000,
    timestamp: 1,
    work: 86.000001
  }
  const resp = {data: [
    {id: 1, name: "Bitcoin Core", version: 170100, best_block: null, unreachable_since: null, ibd: false},
    {id: 2, name: "Bitcoin Core", version: 160300, best_block: best_block, unreachable_since: null, ibd: false}
  ]}
  axios.get.mockResolvedValue(resp);

  const wrapper = shallow(<Nodes match={{params: {coin: 'BTC'}}} />);
  await flushPromises();
  expect(wrapper.find('Chaintip')).toHaveLength(1);
  expect(wrapper.find('NodesWithoutTip')).toHaveLength(1);
});
