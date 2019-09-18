import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Alerts from 'forkMonitorApp/components/alerts';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

axios.get.mockImplementation(url => {
  if (url == "/api/v1/invalid_blocks?coin=BTC") {
    return Promise.resolve({data: [
      {
        id: 1,
        block: {height:582689, timestamp:1558050809, hash: "00000000000000000b6f077cdfc57a62be57c757ec9f8d88d4c2ef8dfc69b141", first_seen_by: {id:3,name:"Bitcoin SV",version:100010000}},
        node: {id:21,name_with_version:"Bitcoin Unlimited 0.10.6"}
      }
    ]})
  } else if (url == "/api/v1/invalid_blocks?coin=BCH") {
    return Promise.resolve({data: [
    ]})
  } else if (url == "/api/v1/inflated_blocks?coin=BCH") {
      return Promise.resolve({data: [
        {
          id: 1,
          block: {height:582689, timestamp:1558050809, hash: "00000000000000000b6f077cdfc57a62be57c757ec9f8d88d4c2ef8dfc69b141", first_seen_by: {id:3,name:"Bitcoin SV",version:100010000}},
          node: {id:21,name_with_version:"Bitcoin Unlimited 0.10.6"}
        }
      ]})
    } else if (url == "/api/v1/inflated_blocks?coin=BTC") {
      return Promise.resolve({data: [
      ]})
    } else {
    return Promise.reject({})
  }
});

test('should show invalid block', async () => {
  const wrapper = mount(<Alerts coin='BTC' />);
  await flushPromises();
  expect(wrapper.text()).toContain("Bitcoin Unlimited");
});

test('should show inflated block', async () => {
  const wrapper = mount(<Alerts coin='BCH' />);
  await flushPromises();
  expect(wrapper.text()).toContain("Bitcoin Unlimited");
});
