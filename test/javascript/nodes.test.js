import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Nodes from 'forkMonitorApp/components/nodes';
import MockCableApp from './__mocks__/cableAppMock'

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
  {id: 1, name: "Bitcoin Core", version: 170100, height: best_block.height, unreachable_since: null, ibd: false},
  {id: 2, name: "Bitcoin Core", version: 160300, height: best_block.height, unreachable_since: null, ibd: false}
]

const mockChaintips = [
  {id: 1, block: best_block, nodes: mockNodes},
]

axios.get.mockImplementation(url => {
  if (url == "/api/v1/nodes/coin/btc") {
    return Promise.resolve({data: mockNodes})
  } else if (url == "/api/v1/chaintips") {
     return Promise.resolve({data: mockChaintips})
  } else {
      return Promise.reject({})
  }
});

test('rendered component', async () => {
  const wrapper = shallow(<Nodes
    cableApp={ MockCableApp }
  />);
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
  mockNodes[0].height = null

  const wrapper = shallow(<Nodes
    cableApp={ MockCableApp }
  />);
  await flushPromises();
  expect(wrapper.find('Chaintip')).toHaveLength(1);
  expect(wrapper.find('NodesWithoutTip')).toHaveLength(1);
});
