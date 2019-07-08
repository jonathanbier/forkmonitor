import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodeName from 'forkMonitorApp/components/nodeName';

const chaintip = {
  hash: "abcd",
  height: 500000,
  timestamp: 1,
  work: 86.000001
}

let wrapper;

describe('NodeName', () => {
  const node = {id: 1, name_with_version: "Bitcoin Core 0.17.1", best_block: chaintip, unreachable_since: null, ibd: false};

  beforeAll(() => {
    wrapper = shallow(<NodeName
      key={ 0 }
      node={ node }
    />)
  });

  test('should display name and version', () => {
    expect(wrapper.text()).toEqual("Bitcoin Core 0.17.1");
  });

});
