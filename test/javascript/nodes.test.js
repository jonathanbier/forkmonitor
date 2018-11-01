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
    work: "1"
  }
  const resp = {data: [
    {pos: 1, name: "Bitcoin Core", version: 1000, best_block: best_block, unreachable_since: null},
    {pos: 2, name: "Bitcoin Core", version: 2000, best_block: best_block, unreachable_since: null}
  ]}
  axios.get.mockResolvedValue(resp);

  const wrapper = shallow(<Nodes />);
  await flushPromises();
  expect(wrapper.find('.node-info')).toHaveLength(2);
});
