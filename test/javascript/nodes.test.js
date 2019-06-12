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

const best_block = {
  hash: "abcd",
  height: 500000,
  timestamp: 1,
  work: 86.000001
}

const mockNodes = [
  {id: 1, name: "Bitcoin Core", version: 170100, best_block: best_block, unreachable_since: null, ibd: false},
  {id: 2, name: "Bitcoin Core", version: 160300, best_block: best_block, unreachable_since: null, ibd: false}
]

axios.get.mockImplementation(url => {
  if (url == "/api/v1/nodes/coin/BTC") {
    return Promise.resolve({data: mockNodes})
  } else if (url == "/api/v1/invalid_blocks?coin=BTC") {
    return Promise.resolve({data: [
      {id: 1, block: {height:582689, timestamp:1558050809, hash: "00000000000000000b6f077cdfc57a62be57c757ec9f8d88d4c2ef8dfc69b141", first_seen_by: {id:3,name:"Bitcoin SV",version:100010000}},"node":{id:21,name:"Bitcoin Unlimited",version:1060000}}
    ]})
  } else {
    throw(false)
  }

})

test('rendered component', async () => {
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
  mockNodes[0].best_block = null
  // const resp = {data: [
  //   {id: 1, name: "Bitcoin Core", version: 170100, best_block: null, unreachable_since: null, ibd: false},
  //   {id: 2, name: "Bitcoin Core", version: 160300, best_block: best_block, unreachable_since: null, ibd: false}
  // ]}
  // axios.get.mockResolvedValue(resp);

  const wrapper = shallow(<Nodes match={{params: {coin: 'BTC'}}} />);
  await flushPromises();
  expect(wrapper.find('Chaintip')).toHaveLength(1);
  expect(wrapper.find('NodesWithoutTip')).toHaveLength(1);
});
