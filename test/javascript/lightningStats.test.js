import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import LightningStats from 'forkMonitorApp/components/lightningStats';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

const mockStats = {
  "count":2,
  "total": 1.33874639 // avoid 2 to keep test simple
}

axios.get.mockImplementation(url => {
  if (url == "/api/v1/ln_stats.json") {
    return Promise.resolve({data: mockStats})
  } else {
      return Promise.reject({})
  }
});

describe('LightningStats', () => {
  let wrapper;

  beforeAll(() => {
    wrapper = mount(<LightningStats />);
  });

  test('should show count', () => {
    expect(wrapper.text()).toContain("2");
  });

  test('should show total', () => {
    expect(wrapper.text()).toContain("1.339");
  });

});
