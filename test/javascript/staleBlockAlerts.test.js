import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import StaleBlockAlerts from 'forkMonitorApp/components/staleBlockAlerts';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

axios.get.mockImplementation(url => {
  if (url == "/api/v1/stale_candidates/btc") {
    return Promise.resolve({data: [{
      height: 10,
      blocks: [
        {
          height: 10
        },
        {
          height: 10
        }]
      }]})
  } else {
    return Promise.reject({})
  }
});


describe('component', () => {
  const component = shallow(<StaleBlockAlerts coin='btc' currentHeight={10} />);

  test('should show stale block alert', async () => {
    await flushPromises();
    expect(component.text()).toContain("<AlertStale />");
  });

  test('should not show stale block alert after a while', async () => {
    component.setProps({currentHeight: 1000});
    await flushPromises();
    expect(component.text()).not.toContain("<AlertStale />");
  });
});
